// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../src/DelegationPolicy.sol";

interface Vm {
    function prank(address) external;
    function expectRevert(bytes4) external;
}

/// @dev Minimal local token with deterministic modes for testing ERC-20 return behavior.
contract MockToken {
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;
    mapping(address account => uint256 amount) public balanceOf;
    uint8 public approveMode; // 0=true, 1=false, 2=revert, 3=no return data

    function setApproveMode(uint8 mode) external {
        approveMode = mode;
    }

    function mint(address account, uint256 amount) external {
        balanceOf[account] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (approveMode == 2) revert("MOCK_APPROVE_REVERT");
        allowance[msg.sender][spender] = amount;
        if (approveMode == 3) assembly ("memory-safe") { return(0, 0) }
        return approveMode != 1;
    }

    function transferFrom(address owner, address recipient, uint256 amount) external returns (bool) {
        uint256 permitted = allowance[owner][msg.sender];
        require(permitted >= amount, "ALLOWANCE");
        require(balanceOf[owner] >= amount, "BALANCE");
        allowance[owner][msg.sender] = permitted - amount;
        balanceOf[owner] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }
}

contract DelegationPolicyTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    DelegationPolicy private policy;
    MockToken private token;
    address private constant SPENDER = address(0xBEEF);
    address private constant RECIPIENT = address(0xCAFE);
    uint128 private constant CAP = 100 ether;

    function setUp() public {
        policy = new DelegationPolicy();
        token = new MockToken();
    }

    function testRejectsExternalCallerForRuleChanges() public {
        vm.expectRevert(DelegationPolicy.OnlyAccountItself.selector);
        policy.setTokenRule(address(token), SPENDER, CAP, true);
    }

    function testRejectsExternalCallerForApproval() public {
        vm.expectRevert(DelegationPolicy.OnlyAccountItself.selector);
        policy.approveWithinCap(address(token), 1 ether);
    }

    function testRejectsExternalCallerForAllowanceCleanup() public {
        _configureRule();
        vm.expectRevert(DelegationPolicy.OnlyAccountItself.selector);
        policy.clearConfiguredApproval(address(token));
    }

    function testRejectsApprovalWithoutRule() public {
        _asAccount();
        vm.expectRevert(DelegationPolicy.TokenNotAllowed.selector);
        policy.approveWithinCap(address(token), 1 ether);
    }

    function testRejectsInvalidEnabledRule() public {
        _asAccount();
        vm.expectRevert(DelegationPolicy.InvalidRule.selector);
        policy.setTokenRule(address(token), address(0), CAP, true);
    }

    function testAllowsApprovalBelowCap() public {
        _configureRule();
        _approve(99 ether);
        require(token.allowance(address(policy), SPENDER) == 99 ether, "below-cap approval missing");
    }

    function testFuzzApprovalAtOrBelowCap(uint128 amount) public {
        amount = uint128(uint256(amount) % (uint256(CAP) + 1));
        _configureRule();
        _approve(amount);
        require(token.allowance(address(policy), SPENDER) == amount, "fuzzed approval mismatch");
    }

    function testAllowsApprovalAtCapAndClearsIt() public {
        _configureRule();
        _approve(CAP);
        require(token.allowance(address(policy), SPENDER) == CAP, "cap approval missing");

        _asAccount();
        policy.clearConfiguredApproval(address(token));
        require(token.allowance(address(policy), SPENDER) == 0, "allowance not cleared");
    }

    function testRejectsApprovalAboveCap() public {
        _configureRule();
        _asAccount();
        vm.expectRevert(DelegationPolicy.ApprovalAboveCap.selector);
        policy.approveWithinCap(address(token), uint256(CAP) + 1);
    }

    function testDisabledRuleBlocksNewApprovalButRetainsOldAllowanceThatCanBeSpent() public {
        _configureRule();
        token.mint(address(policy), 10 ether);
        _approve(10 ether);

        _asAccount();
        // Disabled-rule arguments are ignored so cleanup retains the prior spender.
        policy.setTokenRule(address(token), address(0), 0, false);
        require(token.allowance(address(policy), SPENDER) == 10 ether, "disabling unexpectedly cleared allowance");

        _asAccount();
        vm.expectRevert(DelegationPolicy.TokenNotAllowed.selector);
        policy.approveWithinCap(address(token), 1 ether);

        vm.prank(SPENDER);
        token.transferFrom(address(policy), RECIPIENT, 4 ether);
        require(token.balanceOf(RECIPIENT) == 4 ether, "spender could not use residual allowance");
        require(token.allowance(address(policy), SPENDER) == 6 ether, "residual allowance incorrect");
    }

    function testClearWorksAfterRuleDisabled() public {
        _configureRule();
        _approve(7 ether);
        _asAccount();
        policy.setTokenRule(address(token), address(0), 0, false);
        _asAccount();
        policy.clearConfiguredApproval(address(token));
        require(token.allowance(address(policy), SPENDER) == 0, "disabled rule could not be cleaned up");
    }

    function testRejectsTokenReturningFalse() public {
        _configureRule();
        token.setApproveMode(1);
        _asAccount();
        vm.expectRevert(DelegationPolicy.TokenCallFailed.selector);
        policy.approveWithinCap(address(token), 1 ether);
    }

    function testRejectsTokenCallRevert() public {
        _configureRule();
        token.setApproveMode(2);
        _asAccount();
        vm.expectRevert(DelegationPolicy.TokenCallFailed.selector);
        policy.approveWithinCap(address(token), 1 ether);
    }

    function testAcceptsLegacyTokenWithNoReturnData() public {
        _configureRule();
        token.setApproveMode(3);
        _approve(2 ether);
        require(token.allowance(address(policy), SPENDER) == 2 ether, "legacy approval missing");
    }

    function testRejectsAddressWithoutTokenCode() public {
        _configureRule();
        address tokenWithoutCode = address(0x1234);
        _asAccount();
        policy.setTokenRule(tokenWithoutCode, SPENDER, CAP, true);
        _asAccount();
        vm.expectRevert(DelegationPolicy.TokenCallFailed.selector);
        policy.approveWithinCap(tokenWithoutCode, 1 ether);
    }

    function _configureRule() private {
        _asAccount();
        policy.setTokenRule(address(token), SPENDER, CAP, true);
    }

    function _approve(uint256 amount) private {
        _asAccount();
        policy.approveWithinCap(address(token), amount);
    }

    function _asAccount() private {
        vm.prank(address(policy));
    }
}

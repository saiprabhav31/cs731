// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../src/DelegationPolicy.sol";

interface Vm7702 {
    function addr(uint256 privateKey) external returns (address);
    function prank(address) external;
    function signAndAttachDelegation(address implementation, uint256 privateKey) external;
}

contract LifecycleToken {
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

/// @notice Protocol-level local test of delegation installation, clearing, and ERC-20 allowance state.
contract DelegationLifecycleTest {
    Vm7702 private constant vm = Vm7702(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant OWNER_KEY = 0xA11CE;
    address private constant SPENDER = address(0xBEEF);
    uint128 private constant CAP = 100 ether;

    function testDelegationClearDoesNotClearTokenAllowance() public {
        address owner = vm.addr(OWNER_KEY);
        DelegationPolicy implementation = new DelegationPolicy();
        LifecycleToken token = new LifecycleToken();

        // A signed authorization installs the policy at the EOA. The EOA calls itself,
        // so the delegated code observes msg.sender == address(this).
        vm.signAndAttachDelegation(address(implementation), OWNER_KEY);
        vm.prank(owner);
        (bool configured,) = owner.call(
            abi.encodeCall(DelegationPolicy.setTokenRule, (address(token), SPENDER, CAP, true))
        );
        require(configured, "delegated setup call failed");
        require(owner.code.length == 23, "delegation designator not installed");

        vm.prank(owner);
        (bool approved,) = owner.call(
            abi.encodeCall(DelegationPolicy.approveWithinCap, (address(token), 10 ether))
        );
        require(approved, "delegated approval call failed");
        require(token.allowance(owner, SPENDER) == 10 ether, "allowance not created");

        // A second owner-signed authorization to address(0) clears delegation.
        vm.signAndAttachDelegation(address(0), OWNER_KEY);
        vm.prank(owner);
        (bool reset,) = owner.call("");
        require(reset, "delegation reset transaction failed");
        require(owner.code.length == 0, "delegation code was not cleared");

        // Token storage is independent of account code, so its allowance remains live.
        require(token.allowance(owner, SPENDER) == 10 ether, "reset unexpectedly changed token allowance");

        // The former delegated entry point no longer runs after code is cleared.
        (bool noCodeCall,) = owner.call(
            abi.encodeCall(DelegationPolicy.approveWithinCap, (address(token), 1 ether))
        );
        require(noCodeCall, "empty-code account call unexpectedly reverted");
        require(token.allowance(owner, SPENDER) == 10 ether, "policy ran after delegation reset");

        // Clearing the token approval is a separate call signed/sent by the owner.
        vm.prank(owner);
        bool cleaned = token.approve(SPENDER, 0);
        require(cleaned, "direct allowance cleanup failed");
        require(token.allowance(owner, SPENDER) == 0, "direct cleanup did not clear allowance");
    }
}

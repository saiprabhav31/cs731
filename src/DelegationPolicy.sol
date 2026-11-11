// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice A deliberately small policy module intended to execute as EIP-7702
/// delegated code. It only exposes bounded ERC-20 approval operations.
/// @dev This contract does not set or clear an EOA's delegation. EIP-7702
/// authorization tuples are signed by the EOA and processed by the protocol.
/// When this code runs in an EOA's context, address(this) is that EOA.
interface IERC20Minimal {
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract DelegationPolicy {
    // A custom namespaced slot avoids Solidity's ordinary sequential slots.
    // This is not claimed to be an ERC-7201-derived namespace.
    bytes32 private constant POLICY_SLOT =
        0x3b19d9d1808c53db9a681a6c9ec4c12c4cabd73ea5fc16582df8a17f39a4f900;

    struct TokenRule {
        address spender;
        uint128 approvalCap;
        bool enabled;
    }

    struct PolicyStorage {
        mapping(address token => TokenRule) rules;
    }

    error OnlyAccountItself();
    error InvalidRule();
    error TokenNotAllowed();
    error ApprovalAboveCap();
    error TokenCallFailed();

    event TokenRuleSet(address indexed token, address indexed spender, uint128 cap, bool enabled);
    event ApprovalSubmitted(address indexed token, address indexed spender, uint256 amount);

    /// @notice Set or disable the one allowed spender and maximum approval for a token.
    /// @dev Under delegation this must be invoked by a transaction from the EOA to itself.
    function setTokenRule(address token, address spender, uint128 cap, bool enabled) external {
        _onlyAccountItself();
        if (token == address(0)) revert InvalidRule();
        PolicyStorage storage s = _policyStorage();
        TokenRule storage rule = s.rules[token];
        if (enabled) {
            if (spender == address(0) || cap == 0) revert InvalidRule();
            rule.spender = spender;
            rule.approvalCap = cap;
            rule.enabled = true;
        } else {
            // Keep the old spender so its token-side allowance can still be cleared.
            rule.enabled = false;
            spender = rule.spender;
            cap = rule.approvalCap;
        }
        emit TokenRuleSet(token, spender, cap, enabled);
    }

    /// @notice Set an ERC-20 allowance only for the configured spender and within its cap.
    function approveWithinCap(address token, uint256 amount) external {
        _onlyAccountItself();
        TokenRule memory rule = _policyStorage().rules[token];
        if (!rule.enabled) revert TokenNotAllowed();
        if (amount > rule.approvalCap) revert ApprovalAboveCap();
        _approveToken(token, rule.spender, amount);
        emit ApprovalSubmitted(token, rule.spender, amount);
    }

    /// @notice Ask the token to clear the configured spender's allowance.
    /// @dev This must be done while the delegated code is active. After delegation
    /// is cleared, the owner must call the token directly (or use other active code).
    function clearConfiguredApproval(address token) external {
        _onlyAccountItself();
        TokenRule memory rule = _policyStorage().rules[token];
        if (rule.spender == address(0)) revert TokenNotAllowed();
        _approveToken(token, rule.spender, 0);
        emit ApprovalSubmitted(token, rule.spender, 0);
    }

    /// @notice Read the configured token rule in the current account context.
    function tokenRule(address token)
        external
        view
        returns (address spender, uint128 approvalCap, bool enabled)
    {
        TokenRule memory rule = _policyStorage().rules[token];
        return (rule.spender, rule.approvalCap, rule.enabled);
    }

    function _onlyAccountItself() private view {
        if (msg.sender != address(this)) revert OnlyAccountItself();
    }

    /// @dev Accept standard bool-returning tokens and legacy tokens that return no data.
    /// Reject calls to addresses without code, failed calls, malformed return data, and false.
    function _approveToken(address token, address spender, uint256 amount) private {
        if (token.code.length == 0) revert TokenCallFailed();
        (bool ok, bytes memory data) = token.call(
            abi.encodeCall(IERC20Minimal.approve, (spender, amount))
        );
        if (!ok) revert TokenCallFailed();
        if (data.length == 0) return;
        if (data.length < 32) revert TokenCallFailed();

        uint256 returned;
        assembly ("memory-safe") {
            returned := mload(add(data, 0x20))
        }
        if (returned != 1) revert TokenCallFailed();
    }

    function _policyStorage() private pure returns (PolicyStorage storage s) {
        bytes32 slot = POLICY_SLOT;
        assembly ("memory-safe") {
            s.slot := slot
        }
    }
}

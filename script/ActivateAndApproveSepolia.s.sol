// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../src/DelegationPolicy.sol";
import "./VmSepolia.s.sol";

contract ActivateAndApproveSepolia is SepoliaScriptBase {
    function run() external {
        _requireSepolia();
        uint256 ownerKey = vm.envUint("OWNER_PRIVATE_KEY");
        address policy = vm.envAddress("POLICY_ADDRESS");
        address token = vm.envAddress("TOKEN_ADDRESS");
        address spender = vm.envAddress("SPENDER_ADDRESS");
        address owner = vm.addr(ownerKey);
        require(owner == vm.envAddress("OWNER_ADDRESS"), "OWNER_KEY_ADDRESS_MISMATCH");
        _requireAddress(policy, "POLICY_ADDRESS");
        _requireAddress(token, "TOKEN_ADDRESS");
        _requireAddress(spender, "SPENDER_ADDRESS");

        vm.startBroadcast(ownerKey);
        vm.signAndAttachDelegation(policy, ownerKey);
        (bool configured,) = owner.call(
            abi.encodeCall(DelegationPolicy.setTokenRule, (token, spender, uint128(DEMO_CAP), true))
        );
        require(configured, "DELEGATED_SETUP_FAILED");
        (bool approved,) = owner.call(
            abi.encodeCall(DelegationPolicy.approveWithinCap, (token, DEMO_ALLOWANCE))
        );
        require(approved, "DELEGATED_APPROVAL_FAILED");
        vm.stopBroadcast();
        require(owner.code.length == 23, "DELEGATION_CODE_NOT_PRESENT_AFTER_SIMULATION");
        require(ProjectTokenReader(token).allowance(owner, spender) == DEMO_ALLOWANCE, "ALLOWANCE_MISMATCH");
    }
}

interface ProjectTokenReader {
    function allowance(address owner, address spender) external view returns (uint256);
}

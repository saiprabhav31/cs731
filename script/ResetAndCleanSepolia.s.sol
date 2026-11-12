// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../src/mocks/ProjectTestToken.sol";
import "./VmSepolia.s.sol";

contract ResetAndCleanSepolia is SepoliaScriptBase {
    function run() external {
        _requireSepolia();
        uint256 ownerKey = vm.envUint("OWNER_PRIVATE_KEY");
        address owner = vm.addr(ownerKey);
        require(owner == vm.envAddress("OWNER_ADDRESS"), "OWNER_KEY_ADDRESS_MISMATCH");
        address token = vm.envAddress("TOKEN_ADDRESS");
        address spender = vm.envAddress("SPENDER_ADDRESS");
        address policy = vm.envAddress("POLICY_ADDRESS");
        _requireAddress(token, "TOKEN_ADDRESS");
        _requireAddress(spender, "SPENDER_ADDRESS");
        _requireAddress(policy, "POLICY_ADDRESS");
        bytes memory delegationCode = owner.code;
        require(
            keccak256(delegationCode) == keccak256(abi.encodePacked(hex"ef0100", policy)),
            "OWNER_NOT_DELEGATED_TO_CONFIGURED_POLICY"
        );
        require(
            ProjectTestToken(token).allowance(owner, spender) == DEMO_ALLOWANCE - SPEND_AMOUNT,
            "EXPECTED_RESIDUAL_ALLOWANCE_NOT_FOUND"
        );

        vm.startBroadcast(ownerKey);
        vm.signAndAttachDelegation(address(0), ownerKey);
        (bool reset,) = owner.call("");
        require(reset, "DELEGATION_RESET_FAILED");
        bool cleaned = ProjectTestToken(token).approve(spender, 0);
        require(cleaned, "ALLOWANCE_CLEANUP_FAILED");
        vm.stopBroadcast();
        require(owner.code.length == 0, "DELEGATION_STILL_PRESENT_AFTER_SIMULATION");
        require(ProjectTestToken(token).allowance(owner, spender) == 0, "ALLOWANCE_NOT_ZERO_AFTER_SIMULATION");
    }
}

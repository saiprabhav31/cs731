// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../src/mocks/ProjectTestToken.sol";
import "./VmSepolia.s.sol";

contract SpendResidualAllowanceSepolia is SepoliaScriptBase {
    function run() external {
        _requireSepolia();
        uint256 spenderKey = vm.envUint("SPENDER_PRIVATE_KEY");
        uint256 ownerKey = vm.envUint("OWNER_PRIVATE_KEY");
        address owner = vm.addr(ownerKey);
        address token = vm.envAddress("TOKEN_ADDRESS");
        address spender = vm.addr(spenderKey);
        require(owner == vm.envAddress("OWNER_ADDRESS"), "OWNER_KEY_ADDRESS_MISMATCH");
        _requireAddress(vm.envAddress("SPENDER_ADDRESS"), "SPENDER_ADDRESS");
        require(spender == vm.envAddress("SPENDER_ADDRESS"), "SPENDER_KEY_ADDRESS_MISMATCH");
        _requireAddress(owner, "OWNER_ADDRESS");
        _requireAddress(token, "TOKEN_ADDRESS");

        vm.startBroadcast(spenderKey);
        ProjectTestToken(token).transferFrom(owner, spender, SPEND_AMOUNT);
        vm.stopBroadcast();
        require(ProjectTestToken(token).allowance(owner, spender) == 6 ether, "RESIDUAL_ALLOWANCE_MISMATCH");
        require(ProjectTestToken(token).balanceOf(spender) == SPEND_AMOUNT, "SPENDER_BALANCE_MISMATCH");
    }
}

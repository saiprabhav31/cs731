// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../src/mocks/ProjectTestToken.sol";
import "./VmSepolia.s.sol";

contract MintOwnerTokensSepolia is SepoliaScriptBase {
    function run() external {
        _requireSepolia();
        uint256 ownerKey = vm.envUint("OWNER_PRIVATE_KEY");
        address owner = vm.addr(ownerKey);
        address token = vm.envAddress("TOKEN_ADDRESS");
        require(owner == vm.envAddress("OWNER_ADDRESS"), "OWNER_KEY_ADDRESS_MISMATCH");
        _requireAddress(token, "TOKEN_ADDRESS");

        vm.startBroadcast(ownerKey);
        ProjectTestToken(token).mint(owner, 1000 ether);
        vm.stopBroadcast();
        require(ProjectTestToken(token).balanceOf(owner) >= 1000 ether, "OWNER_TOKEN_MINT_FAILED");
    }
}

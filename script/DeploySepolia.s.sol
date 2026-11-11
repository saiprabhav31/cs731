// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../src/DelegationPolicy.sol";
import "../src/mocks/ProjectTestToken.sol";
import "./VmSepolia.s.sol";

contract DeploySepolia is SepoliaScriptBase {
    event DemoDeployed(address indexed owner, address indexed policy, address indexed token);

    function run() external {
        _requireSepolia();
        uint256 ownerKey = vm.envUint("OWNER_PRIVATE_KEY");
        address owner = vm.addr(ownerKey);

        vm.startBroadcast(ownerKey);
        DelegationPolicy policy = new DelegationPolicy();
        ProjectTestToken token = new ProjectTestToken();
        token.mint(owner, 1000 ether);
        vm.stopBroadcast();
        emit DemoDeployed(owner, address(policy), address(token));
        require(token.balanceOf(owner) == 1000 ether, "TOKEN_MINT_SIMULATION_FAILED");
    }
}

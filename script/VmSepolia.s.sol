// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface VmSepolia {
    function envUint(string calldata name) external returns (uint256);
    function envAddress(string calldata name) external returns (address);
    function addr(uint256 privateKey) external returns (address);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
    function signAndAttachDelegation(address implementation, uint256 privateKey) external;
}

abstract contract SepoliaScriptBase {
    VmSepolia internal constant vm = VmSepolia(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 internal constant DEMO_CAP = 100 ether;
    uint256 internal constant DEMO_ALLOWANCE = 10 ether;
    uint256 internal constant SPEND_AMOUNT = 4 ether;

    error WrongNetwork(uint256 actualChainId);
    error InvalidAddress(string variableName);

    function _requireSepolia() internal view {
        if (block.chainid != SEPOLIA_CHAIN_ID) revert WrongNetwork(block.chainid);
    }

    function _requireAddress(address value, string memory variableName) internal pure {
        if (value == address(0)) revert InvalidAddress(variableName);
    }
}

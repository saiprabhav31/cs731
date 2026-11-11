// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Testnet-only ERC-20-like token used by the public Sepolia demo.
/// @dev Anyone can mint; never use this contract as a real asset.
contract ProjectTestToken {
    string public constant name = "Delegation Demo Token";
    string public constant symbol = "DDT";
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    function mint(address to, uint256 amount) external {
        require(to != address(0), "ZERO_RECIPIENT");
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address owner, address to, uint256 amount) external returns (bool) {
        uint256 permitted = allowance[owner][msg.sender];
        require(permitted >= amount, "ALLOWANCE");
        require(balanceOf[owner] >= amount, "BALANCE");
        allowance[owner][msg.sender] = permitted - amount;
        balanceOf[owner] -= amount;
        balanceOf[to] += amount;
        emit Transfer(owner, to, amount);
        emit Approval(owner, msg.sender, permitted - amount);
        return true;
    }
}

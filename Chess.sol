//ERC20 Chess
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";

contract ERC20 is IERC20 {
    // Define state variables
    string public constant name = "chess"; // Token name
    string public constant symbol = "CHESS"; // Token symbol
    uint8 public constant decimals = 18; // Token decimals
    uint256 public totalSupply; // Total token supply
    uint256 public maxSupply; // Maximum token supply
    address public stakingContract; // Address of the StakingContract
    mapping(address => uint256) public balanceOf; // Tracks token balances for each address
    mapping(address => mapping(address => uint256)) public allowance; // Tracks approved spending limits

    // Define events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value);

    // Constructor to initialize the contract
    constructor(uint256 _initialSupply, uint256 _maxSupply) {
        totalSupply = _initialSupply * (10 ** uint256(decimals)); // Set initial token supply
        maxSupply = _maxSupply * (10 ** uint256(decimals)); // Set maximum token supply
        require(totalSupply <= maxSupply, "Initial supply cannot exceed max supply");

        // Allocate initial supply to the specified address
        balanceOf[0xd4119984721C080adE9Cfa9b2a062a48a10592d5] = totalSupply;

        // Emit Transfer event
        emit Transfer(address(0), 0xd4119984721C080adE9Cfa9b2a062a48a10592d5, totalSupply);
    }

    // Function to transfer tokens from one address to another
    function transfer(address _to, uint256 _value) external override returns (bool) {
        require(_to != address(0), "ERC20: transfer to the zero address");
        require(balanceOf[msg.sender] >= _value, "ERC20: insufficient balance");

        // Transfer tokens
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;

        // Emit Transfer event
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    // Function to approve spending of tokens by another address
    function approve(address _spender, uint256 _value) external override returns (bool) {
        // Approve spending limit
        allowance[msg.sender][_spender] = _value;

        // Emit Approval event
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    // Function to transfer tokens on behalf of another address
    function transferFrom(address _from, address _to, uint256 _value) external override returns (bool) {
        require(_from != address(0), "ERC20: transfer from the zero address");
        require(_to != address(0), "ERC20: transfer to the zero address");
        require(balanceOf[_from] >= _value, "ERC20: insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "ERC20: insufficient allowance");

        // Transfer tokens
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;

        // Emit Transfer event
        emit Transfer(_from, _to, _value);
        return true;
    }

    // Function to mint new tokens (can only be called by the StakingContract)
    function mint(address _to, uint256 _value) external {
        require(msg.sender == stakingContract, "ERC20: caller is not the StakingContract");
        require(totalSupply + _value <= maxSupply, "ERC20: total supply exceeds max supply");

        // Mint new tokens
        balanceOf[_to] += _value;
        totalSupply += _value;

        // Emit Mint event
        emit Mint(_to, _value);
    }

    // Function to set the address of the StakingContract (can only be called once)
    function setStakingContract(address _stakingContract) external {
        require(stakingContract == address(0), "ERC20: staking contract address has already been set");
        stakingContract = _stakingContract;
    }
}

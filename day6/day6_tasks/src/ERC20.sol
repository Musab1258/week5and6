// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ERC20 Token Standard Implementation
 * @dev Complete ERC20 implementation from scratch without using any libraries
 * @notice This contract implements the ERC20 token standard as defined in EIP-20
 * 
 * ERC20 Standard Requirements:
 * - Required Functions: totalSupply, balanceOf, transfer, transferFrom, approve, allowance
 * - Optional Functions: name, symbol, decimals
 * - Required Events: Transfer, Approval
 * - All functions must return boolean success indicators
 * - Zero value transfers must be treated as normal transfers
 */

import "./IERC20.sol";

contract ERC20 is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    // Total supply of tokens
    uint256 private _totalSupply;

    // Maximum supply cap
    uint256 private _maxSupply;

    // Owner of the contract (the only address allowed to mint)
    address private _owner;

    // Mapping from address to balance
    mapping(address => uint256) private _balances;

    // Mapping from owner to spender to allowance amount
    // allowance[owner][spender] = amount
    mapping(address => mapping(address => uint256)) private _allowances;

    modifier onlyOwner() {
        require(msg.sender == _owner, "ERC20: caller is not the owner");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialSupply_,
        uint256 maxSupply_
    ) {
        require(maxSupply_ > 0, "ERC20: max supply must be greater than zero");
        require(initialSupply_ <= maxSupply_, "ERC20: initial supply exceeds max supply");

        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _maxSupply = maxSupply_ * 10**decimals_;
        _owner = msg.sender;
        _totalSupply = initialSupply_ * 10**decimals_;
        _balances[msg.sender] = _totalSupply;

        // Emit Transfer event for initial supply (from zero address to deployer)
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    function mint(address account, uint256 amount) public onlyOwner {
        uint256 scaledAmount = amount * 10**_decimals;
        require(_totalSupply + scaledAmount <= _maxSupply, "ERC20: mint would exceed max supply");
        _mint(account, scaledAmount);
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        
        // Safe math: unchecked is safe because we've already checked fromBalance >= amount
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
    }
}

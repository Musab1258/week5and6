// Write a smart contract that can save both ERC20 and ether for a user.

// Users must be able to:
// check individual balances,
// deposit or save in the contract.
// withdraw their savings

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Save {
    mapping(address => uint256) public etherBalances;
    mapping(address => mapping(address => uint256)) public tokenBalances;

    event EtherDeposited(address indexed user, uint256 amount);
    event EtherWithdrawn(address indexed user, uint256 amount);
    event TokenDeposited(address indexed user, address indexed token, uint256 amount);
    event TokenWithdrawn(address indexed user, address indexed token, uint256 amount);

    receive() external payable {
        etherBalances[msg.sender] += msg.value;
        emit EtherDeposited(msg.sender, msg.value);
    }

    function depositEther() external payable {
        require(msg.value > 0, "Save: Must deposit more than zero");
        etherBalances[msg.sender] += msg.value;
        emit EtherDeposited(msg.sender, msg.value);
    }

    function depositToken(address tokenAddress, uint256 amount) external {
        require(tokenAddress != address(0), "Save: Invalid token address");
        require(amount > 0, "Save: Deposit amount must be greater than zero");

        IERC20 token = IERC20(tokenAddress);
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Save: Token transfer failed");

        tokenBalances[msg.sender][tokenAddress] += amount;

        emit TokenDeposited(msg.sender, tokenAddress, amount);
    }

    function withdrawEther(uint256 amount) external {
        require(amount > 0, "Save: Withdrawal amount must be greater than zero");
        require(etherBalances[msg.sender] >= amount, "Save: Insufficient Ether balance");

        etherBalances[msg.sender] -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Save: Ether transfer failed");

        emit EtherWithdrawn(msg.sender, amount);
    }

    function withdrawToken(address tokenAddress, uint256 amount) external {
        require(tokenAddress != address(0), "Save: Invalid token address");
        require(amount > 0, "Save: Withdrawal amount must be greater than zero");
        require(tokenBalances[msg.sender][tokenAddress] >= amount, "Save: Insufficient token balance");

        IERC20 token = IERC20(tokenAddress);

        tokenBalances[msg.sender][tokenAddress] -= amount;
        bool success = token.transfer(msg.sender, amount);
        require(success, "Save: Token transfer failed");

        emit TokenWithdrawn(msg.sender, tokenAddress, amount);
    }

    function getEtherBalance(address user) external view returns (uint256) {
        return etherBalances[user];
    }

    function getTokenBalance(address user, address tokenAddress) external view returns (uint256) {
        return tokenBalances[user][tokenAddress];
    }

    function getContractEtherBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getContractTokenBalance(address tokenAddress) external view returns (uint256) {
        IERC20 token = IERC20(tokenAddress);
        return token.balanceOf(address(this));
    }
}
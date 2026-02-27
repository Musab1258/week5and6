// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./MultisigWallet.sol";

contract MultisigFactory {
    // Events
    event WalletCreated(address indexed walletAddress, address[] owners, uint256 threshold, address indexed creator);

    // Keep track of all wallets created by this factory
    MultisigWallet[] public deployedWallets;

    // Deploy a new MultisigWallet
    function createWallet(address[] memory _owners, uint256 _threshold) external returns (address) {
        MultisigWallet newWallet = new MultisigWallet(_owners, _threshold);
        
        deployedWallets.push(newWallet);

        emit WalletCreated(address(newWallet), _owners, _threshold, msg.sender);

        return address(newWallet);
    }

    // Helper to get number of deployed wallets
    function getWalletsCount() external view returns (uint256) {
        return deployedWallets.length;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/MultisigFactory.sol";
import "../src/MultisigWallet.sol";

contract MultisigTest is Test {
    MultisigFactory factory;
    MultisigWallet wallet;

    address owner1 = address(0x11);
    address owner2 = address(0x22);
    address owner3 = address(0x33);
    address nonOwner = address(0x44);

    function setUp() public {
        // 1. Deploy Factory
        factory = new MultisigFactory();

        // 2. Prepare Owners
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        // 3. Create Wallet
        address walletAddr = factory.createWallet(owners, 2);
        wallet = MultisigWallet(payable(walletAddr));

        // 4. Fund Wallet
        vm.deal(address(wallet), 10 ether);
    }

    function testFactoryDeployment() public view {
        address[] memory storedOwners = wallet.getOwners();
        assertEq(storedOwners.length, 3);
        assertEq(storedOwners[0], owner1);
        assertEq(wallet.threshold(), 2);
    }

    function testSubmitTransaction() public {
        vm.startPrank(owner1);
        
        wallet.submitTransaction(owner3, 1 ether, "");
        
        (address to, uint256 value, , bool executed, uint256 numConfirmations) = wallet.getTransaction(0);
        
        assertEq(to, owner3);
        assertEq(value, 1 ether);
        assertEq(executed, false);
        assertEq(numConfirmations, 0);
        
        vm.stopPrank();
    }

    function testExecuteTransaction() public {
        vm.prank(owner1);
        wallet.submitTransaction(owner3, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        uint256 balanceBefore = owner3.balance;
        
        vm.prank(owner1);
        wallet.executeTransaction(0);

        uint256 balanceAfter = owner3.balance;

        (,,, bool executed,) = wallet.getTransaction(0);
        assertTrue(executed);
        assertEq(balanceAfter - balanceBefore, 1 ether);
    }

    function testRevokeConfirmation() public {
        vm.startPrank(owner1);
        wallet.submitTransaction(owner3, 1 ether, "");
        wallet.confirmTransaction(0);
        
        (,,,, uint256 confBefore) = wallet.getTransaction(0);
        assertEq(confBefore, 1);

        wallet.revokeConfirmation(0);
        
        (,,,, uint256 confAfter) = wallet.getTransaction(0);
        assertEq(confAfter, 0);
        vm.stopPrank();
    }

    function testRevert_NonOwnerSubmit() public {
        vm.startPrank(nonOwner); 
        
        vm.expectRevert("Not an owner"); 
        
        wallet.submitTransaction(owner3, 1 ether, "");
        
        vm.stopPrank();
    }
}
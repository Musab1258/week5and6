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
        // 1. Deploy the Factory
        factory = new MultisigFactory();

        // 2. Prepare arguments for the Child
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        // 3. Create the Child Wallet via Factory
        address walletAddr = factory.createWallet(owners, 2);
        
        // 4. Point our variable to the new address
        wallet = MultisigWallet(payable(walletAddr));
        
        // 5. Fund the wallet to test execution
        vm.deal(address(wallet), 10 ether);
    }

    // TEST 1: Check Factory Deployment
    function testFactoryDeployment() public {
        // Check if owners were set correctly in the child
        address[] memory storedOwners = wallet.getOwners();
        assertEq(storedOwners.length, 3);
        assertEq(storedOwners[0], owner1);
        assertEq(wallet.threshold(), 2);
    }

    // TEST 2: Submit Transaction
    function testSubmitTransaction() public {
        // Prank: Act as owner1
        vm.startPrank(owner1);
        
        // Send 1 ether to owner3
        bytes memory data = "";
        wallet.submitTransaction(owner3, 1 ether, data);
        
        // Verify tx exists
        (address to, uint256 value, , bool executed, uint256 numConfirmations) = wallet.getTransaction(0);
        
        assertEq(to, owner3);
        assertEq(value, 1 ether);
        assertEq(executed, false);
        assertEq(numConfirmations, 0);
        
        vm.stopPrank();
    }

    // TEST 3: Confirm and Execute Flow
    function testExecuteTransaction() public {
        // 1. Submit (by Owner 1)
        vm.prank(owner1);
        wallet.submitTransaction(owner3, 1 ether, "");

        // 2. Confirm (by Owner 1)
        vm.prank(owner1);
        wallet.confirmTransaction(0);

        // 3. Confirm (by Owner 2)
        vm.prank(owner2);
        wallet.confirmTransaction(0);

        // Check confirmation count
        (,,,, uint256 numConfirmations) = wallet.getTransaction(0);
        assertEq(numConfirmations, 2);

        // 4. Execute 
        uint256 balanceBefore = owner3.balance;
        
        vm.prank(owner1);
        wallet.executeTransaction(0);

        uint256 balanceAfter = owner3.balance;

        // Verify Execution
        (,,, bool executed,) = wallet.getTransaction(0);
        assertTrue(executed);
        assertEq(balanceAfter - balanceBefore, 1 ether);
    }

    // TEST 4: Security (Revoke)
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

    // TEST 5: Security (Non-owner cannot submit)
    function testFailNonOwnerSubmit() public {
        vm.prank(nonOwner); 
        wallet.submitTransaction(owner3, 1 ether, "");
    }
}
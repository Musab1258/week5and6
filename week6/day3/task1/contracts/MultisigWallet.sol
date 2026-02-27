// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

contract MultisigWallet {
    // Events
    event TransactionSubmitted(uint indexed txId, address indexed to, uint256 value, bytes data);
    event TransactionApproved(uint256 indexed txId, address indexed owner);
    event TransactionExecuted(uint256 indexed txId);

    address[] public owners;
    uint256 public threshold;
    
    mapping(address => bool) public isOwnerMap;
    
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 approvalCount;
        mapping(address => bool) approvals; // Track approvals by owner address
    }

    Transaction[] public transactions;

    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "Owners required");
        require(_threshold > 0 && _threshold <= _owners.length, "Invalid threshold");
        
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwnerMap[owner], "Owner not unique");
            isOwnerMap[owner] = true;
            owners.push(owner);
        }
        threshold = _threshold;
    }

    modifier onlyOwner() {
        require(isOwnerMap[msg.sender], "Not an owner");
        _;
    }

    function submitTransaction(address _to, uint256 _value, bytes memory _data) external onlyOwner {
        Transaction storage txn = transactions.push();
        txn.to = _to;
        txn.value = _value;
        txn.data = _data;
        txn.executed = false;
        txn.approvalCount = 0;

        emit TransactionSubmitted(transactions.length - 1, _to, _value, _data);
    }

    function approveTransaction(uint256 _txId) external onlyOwner {
        require(_txId < transactions.length, "Invalid transaction ID");
        Transaction storage txn = transactions[_txId];
        require(!txn.executed, "Transaction already executed");
        require(!txn.approvals[msg.sender], "Already approved");

        txn.approvals[msg.sender] = true;
        txn.approvalCount += 1;
        emit TransactionApproved(_txId, msg.sender);
    }

    function executeTransaction(uint256 _txId) external onlyOwner {
        require(_txId < transactions.length, "Invalid transaction ID");
        Transaction storage txn = transactions[_txId];
        require(!txn.executed, "Transaction already executed");
        require(txn.approvalCount >= threshold, "Not enough approvals");

        txn.executed = true;
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Transaction execution failed");
        
        emit TransactionExecuted(_txId);
    }

    receive() external payable {}
}

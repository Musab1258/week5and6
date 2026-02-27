// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MultisigWallet {
    // Events
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(address indexed owner, uint256 indexed txId, address indexed to, uint256 value, bytes data);
    event ConfirmTransaction(address indexed owner, uint256 indexed txId);
    event RevokeConfirmation(address indexed owner, uint256 indexed txId);
    event ExecuteTransaction(address indexed owner, uint256 indexed txId);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event ThresholdChanged(uint256 newThreshold);

    // State Variables
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    
    Transaction[] public transactions;

    // Modifiers
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier onlyWallet() {
        require(msg.sender == address(this), "Only wallet can call this");
        _;
    }

    modifier txExists(uint256 _txId) {
        require(_txId < transactions.length, "Tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].executed, "Tx already executed");
        _;
    }

    modifier notConfirmed(uint256 _txId) {
        require(!isConfirmed[_txId][msg.sender], "Tx already confirmed");
        _;
    }

    // Constructor
    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "Owners required");
        require(_threshold > 0 && _threshold <= _owners.length, "Invalid threshold");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        threshold = _threshold;
    }

    // Core Logic

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwner {
        uint256 txId = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 0
        }));

        emit SubmitTransaction(msg.sender, txId, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txId)
        external
        onlyOwner
        txExists(_txId)
        notExecuted(_txId)
        notConfirmed(_txId)
    {
        Transaction storage txn = transactions[_txId];
        txn.numConfirmations += 1;
        isConfirmed[_txId][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txId);
    }

    function revokeConfirmation(uint256 _txId)
        external
        onlyOwner
        txExists(_txId)
        notExecuted(_txId)
    {
        require(isConfirmed[_txId][msg.sender], "Tx not confirmed");

        Transaction storage txn = transactions[_txId];
        txn.numConfirmations -= 1;
        isConfirmed[_txId][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txId);
    }

    function executeTransaction(uint256 _txId)
        external
        onlyOwner
        txExists(_txId)
        notExecuted(_txId)
    {
        Transaction storage txn = transactions[_txId];
        require(txn.numConfirmations >= threshold, "Cannot execute: Not enough confirmations");

        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Tx failed");

        emit ExecuteTransaction(msg.sender, _txId);
    }

    // Wallet Management This must be called via executeTransaction

    function addOwner(address _newOwner, uint256 _newThreshold) external onlyWallet {
        require(_newOwner != address(0), "Invalid owner");
        require(!isOwner[_newOwner], "Already owner");
        require(_newThreshold > 0 && _newThreshold <= owners.length + 1, "Invalid threshold");

        isOwner[_newOwner] = true;
        owners.push(_newOwner);
        threshold = _newThreshold;

        emit OwnerAdded(_newOwner);
        emit ThresholdChanged(_newThreshold);
    }

    function removeOwner(address _owner) external onlyWallet {
        require(isOwner[_owner], "Not an owner");
        
        isOwner[_owner] = false;
        for (uint256 i = 0; i < owners.length - 1; i++) {
            if (owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        }
        owners.pop();

        if (threshold > owners.length) {
            threshold = owners.length;
            emit ThresholdChanged(threshold);
        }

        require(owners.length > 0, "Cannot remove last owner");

        emit OwnerRemoved(_owner);
    }

    function changeThreshold(uint256 _newThreshold) external onlyWallet {
        require(_newThreshold > 0 && _newThreshold <= owners.length, "Invalid threshold");
        threshold = _newThreshold;
        emit ThresholdChanged(_newThreshold);
    }

    // View Helpers

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _txId)
        external
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage txn = transactions[_txId];
        return (
            txn.to,
            txn.value,
            txn.data,
            txn.executed,
            txn.numConfirmations
        );
    }
}
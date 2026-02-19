// Create a School management system where people can:

// Register students & Staffs.
// Pay School fees on registration using the ERC20 token we created.
// Pay staffs also.
// Get the students and their details.
// Get all Staffs.
// Pricing is based on grade / levels from 100 - 400 level.
// Payment status can be updated once the payment is made which should include the timestamp.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract SchoolManagement {

    // Types 

    enum PaymentStatus {
        PENDING,
        COMPLETED
    }

    struct Payment {
        PaymentStatus status;
        uint256 timestamp;
        uint256 amount;
        uint16 level;
    }

    struct Student {
        string name;
        uint8 age;
        uint256 id;
        uint16 level;
        address studentAddress;
        Payment payment;
    }

    struct Staff {
        string name;
        uint256 id;
        address staffAddress;
        uint256 totalPaid;
    }

    // State

    address public admin;
    IERC20 public schoolToken;

    // Level => fee amount (in token units)
    mapping(uint16 => uint256) public levelFees;

    // ID => Student / Staff
    mapping(uint256 => Student) public students;
    mapping(uint256 => Staff) public staffs;

    // Address => ID (to prevent duplicate registrations)
    mapping(address => uint256) public studentIdByAddress;
    mapping(address => uint256) public staffIdByAddress;

    // Track registered IDs
    uint256[] public studentIds;
    uint256[] public staffIds;

    // Events

    event StudentRegistered(uint256 indexed id, string name, uint16 level);
    event StaffRegistered(uint256 indexed id, string name);
    event PaymentUpdated(uint256 indexed studentId, uint256 amount, uint256 timestamp);
    event StaffPaid(uint256 indexed staffId, uint256 amount, uint256 timestamp);

    // Modifiers

    modifier onlyAdmin() {
        require(msg.sender == admin, "SchoolManagement: Not admin");
        _;
    }

    // Constructor

    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "SchoolManagement: Invalid token address");

        admin = msg.sender;
        schoolToken = IERC20(_tokenAddress);

        // Set default fees per level
        levelFees[100] = 1000 * 10**18;
        levelFees[200] = 1500 * 10**18;
        levelFees[300] = 2000 * 10**18;
        levelFees[400] = 2500 * 10**18;
    }

    // Admin

    function setLevelFee(uint16 _level, uint256 _fee) external onlyAdmin {
        require(_isValidLevel(_level), "SchoolManagement: Invalid level");
        require(_fee > 0, "SchoolManagement: Fee must be greater than zero");
        levelFees[_level] = _fee;
    }

    // Student Registration

    function registerStudent(
        string memory _name,
        uint8 _age,
        uint16 _level,
        uint256 _id
    ) external {
        require(_age >= 10, "SchoolManagement: Age must be at least 10");
        require(_isValidLevel(_level), "SchoolManagement: Level must be 100, 200, 300, or 400");
        require(students[_id].id == 0, "SchoolManagement: Student ID already exists");
        require(studentIdByAddress[msg.sender] == 0, "SchoolManagement: Address already registered");

        uint256 fee = levelFees[_level];
        require(fee > 0, "SchoolManagement: No fee set for this level");

        // Transfer fee from student to contract
        bool success = schoolToken.transferFrom(msg.sender, address(this), fee);
        require(success, "SchoolManagement: Token transfer failed");

        // Build payment record — mark COMPLETED since fee was paid on registration
        Payment memory payment = Payment({
            status: PaymentStatus.COMPLETED,
            timestamp: block.timestamp,
            amount: fee,
            level: _level
        });

        students[_id] = Student({
            name: _name,
            age: _age,
            id: _id,
            level: _level,
            studentAddress: msg.sender,
            payment: payment
        });

        studentIdByAddress[msg.sender] = _id;
        studentIds.push(_id);

        emit StudentRegistered(_id, _name, _level);
        emit PaymentUpdated(_id, fee, block.timestamp);
    }

    // Staff Registration

    function registerStaff(
        string memory _name,
        uint256 _id
    ) external onlyAdmin {
        require(staffs[_id].id == 0, "SchoolManagement: Staff ID already exists");
        require(staffIdByAddress[msg.sender] == 0, "SchoolManagement: Address already registered");
        require(bytes(_name).length > 0, "SchoolManagement: Name cannot be empty");

        staffs[_id] = Staff({
            name: _name,
            id: _id,
            staffAddress: msg.sender,
            totalPaid: 0
        });

        staffIdByAddress[msg.sender] = _id;
        staffIds.push(_id);

        emit StaffRegistered(_id, _name);
    }

    // Pay Staff

    function payStaff(uint256 _staffId, uint256 _amount) external onlyAdmin {
        Staff storage staff = staffs[_staffId];
        require(staff.id != 0, "SchoolManagement: Staff not found");
        require(_amount > 0, "SchoolManagement: Amount must be greater than zero");

        bool success = schoolToken.transfer(staff.staffAddress, _amount);
        require(success, "SchoolManagement: Token transfer failed");

        staff.totalPaid += _amount;

        emit StaffPaid(_staffId, _amount, block.timestamp);
    }

    // Views

    function getStudentDetails(uint256 _id) external view returns (Student memory) {
        require(students[_id].id != 0, "SchoolManagement: Student not found");
        return students[_id];
    }

    function getStaffDetails(uint256 _id) external view returns (Staff memory) {
        require(staffs[_id].id != 0, "SchoolManagement: Staff not found");
        return staffs[_id];
    }

    function getAllStudentIds() external view returns (uint256[] memory) {
        return studentIds;
    }

    function getAllStaffIds() external view returns (uint256[] memory) {
        return staffIds;
    }

    function getLevelFee(uint16 _level) external view returns (uint256) {
        require(_isValidLevel(_level), "SchoolManagement: Invalid level");
        return levelFees[_level];
    }

    function getContractTokenBalance() external view returns (uint256) {
        return schoolToken.balanceOf(address(this));
    }

    // Internal Helpers

    function _isValidLevel(uint16 _level) internal pure returns (bool) {
        return _level == 100 || _level == 200 || _level == 300 || _level == 400;
    }
}
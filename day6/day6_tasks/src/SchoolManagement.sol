// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "./IERC20.sol";

contract SchoolManagement {

    // Types
    enum PaymentStatus {
        PENDING,
        COMPLETED
    }

    enum StaffStatus {
        ACTIVE,
        SUSPENDED
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
        bool isEnrolled; // false once removed
    }

    struct Staff {
        string name;
        uint256 id;
        address staffAddress;
        uint256 totalPaid;
        StaffStatus status;
    }

    // State
    address public admin;
    IERC20 public schoolToken;

    mapping(uint16 => uint256) public levelFees;

    mapping(uint256 => Student) public students;
    mapping(uint256 => Staff) public staffs;

    mapping(address => uint256) public studentIdByAddress;
    mapping(address => uint256) public staffIdByAddress;

    uint256[] public studentIds;
    uint256[] public staffIds;

    // Events
    event StudentRegistered(uint256 indexed id, string name, uint16 level);
    event StudentRemoved(uint256 indexed id, string name);
    event StaffEmployed(uint256 indexed id, string name, address staffAddress);
    event StaffSuspended(uint256 indexed id, string name);
    event StaffReinstated(uint256 indexed id, string name);
    event PaymentUpdated(uint256 indexed studentId, uint256 amount, uint256 timestamp);
    event StaffPaid(uint256 indexed staffId, uint256 amount, uint256 timestamp);

    // Modifiers
    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() internal view {
        require(msg.sender == admin, "SchoolManagement: Not admin");
    }

    // Constructor
    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "SchoolManagement: Invalid token address");

        admin = msg.sender;
        schoolToken = IERC20(_tokenAddress);

        levelFees[100] = 1000 * 10 ** 18;
        levelFees[200] = 1500 * 10 ** 18;
        levelFees[300] = 2000 * 10 ** 18;
        levelFees[400] = 2500 * 10 ** 18;
    }

    // Admin — Fees
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

        bool success = schoolToken.transferFrom(msg.sender, address(this), fee);
        require(success, "SchoolManagement: Token transfer failed");

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
            payment: payment,
            isEnrolled: true
        });

        studentIdByAddress[msg.sender] = _id;
        studentIds.push(_id);

        emit StudentRegistered(_id, _name, _level);
        emit PaymentUpdated(_id, fee, block.timestamp);
    }

    // Remove Student
    function removeStudent(uint256 _id) external onlyAdmin {
        Student storage student = students[_id];
        require(student.id != 0, "SchoolManagement: Student not found");
        require(student.isEnrolled, "SchoolManagement: Student already removed");

        student.isEnrolled = false;

        // Free up the address so it is not permanently locked
        delete studentIdByAddress[student.studentAddress];

        // Remove from the studentIds array
        _removeFromArray(studentIds, _id);

        emit StudentRemoved(_id, student.name);
    }

    // Staff — Employ (Register)
    function employStaff(
        string memory _name,
        uint256 _id,
        address _staffAddress
    ) external onlyAdmin {
        require(bytes(_name).length > 0, "SchoolManagement: Name cannot be empty");
        require(_staffAddress != address(0), "SchoolManagement: Invalid staff address");
        require(staffs[_id].id == 0, "SchoolManagement: Staff ID already exists");
        require(staffIdByAddress[_staffAddress] == 0, "SchoolManagement: Address already registered");

        staffs[_id] = Staff({
            name: _name,
            id: _id,
            staffAddress: _staffAddress,
            totalPaid: 0,
            status: StaffStatus.ACTIVE
        });

        staffIdByAddress[_staffAddress] = _id;
        staffIds.push(_id);

        emit StaffEmployed(_id, _name, _staffAddress);
    }

    // Staff — Suspend / Reinstate
    function suspendStaff(uint256 _staffId) external onlyAdmin {
        Staff storage staff = staffs[_staffId];
        require(staff.id != 0, "SchoolManagement: Staff not found");
        require(staff.status == StaffStatus.ACTIVE, "SchoolManagement: Staff already suspended");

        staff.status = StaffStatus.SUSPENDED;

        emit StaffSuspended(_staffId, staff.name);
    }

    function reinstateStaff(uint256 _staffId) external onlyAdmin {
        Staff storage staff = staffs[_staffId];
        require(staff.id != 0, "SchoolManagement: Staff not found");
        require(staff.status == StaffStatus.SUSPENDED, "SchoolManagement: Staff is not suspended");

        staff.status = StaffStatus.ACTIVE;

        emit StaffReinstated(_staffId, staff.name);
    }

    // Staff — Pay
    function payStaff(uint256 _staffId, uint256 _amount) external onlyAdmin {
        Staff storage staff = staffs[_staffId];
        require(staff.id != 0, "SchoolManagement: Staff not found");
        require(staff.status == StaffStatus.ACTIVE, "SchoolManagement: Cannot pay a suspended staff member");
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

    function _removeFromArray(uint256[] storage arr, uint256 value) internal {
        uint256 len = arr.length;
        for (uint256 i = 0; i < len; i++) {
            if (arr[i] == value) {
                arr[i] = arr[len - 1];
                arr.pop();
                return;
            }
        }
    }
}

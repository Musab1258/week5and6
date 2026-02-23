// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PropertyMarketplace is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant PROPERTY_MANAGER_ROLE = keccak256("PROPERTY_MANAGER_ROLE");

    IERC20 public paymentToken;
    uint256 private _nextId;

    struct Property {
        uint256 id;
        string name;
        string location;
        string description;
        uint256 price;
        address owner;
        bool isForSale;
        bool exists;
    }

    mapping(uint256 => Property) public properties;
    
    uint256[] private _propertyIds;

    event PropertyCreated(uint256 indexed id, string name, uint256 price, address owner);
    event PropertyRemoved(uint256 indexed id);
    event PropertyPurchased(uint256 indexed id, address indexed buyer, address indexed seller, uint256 price);
    event PropertyPriceUpdated(uint256 indexed id, uint256 newPrice);
    event PropertySaleStatusChanged(uint256 indexed id, bool isForSale);

    modifier onlyPropertyOwner(uint256 _id) {
        require(properties[_id].owner == msg.sender, "Not the property owner");
        _;
    }

    modifier propertyExists(uint256 _id) {
        require(properties[_id].exists, "Property does not exist");
        _;
    }

    constructor(address _paymentToken) {
        require(_paymentToken != address(0), "Invalid token address");
        paymentToken = IERC20(_paymentToken);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PROPERTY_MANAGER_ROLE, msg.sender);
    }

    function createProperty(
        string memory _name,
        string memory _location,
        string memory _description,
        uint256 _price
    ) external onlyRole(PROPERTY_MANAGER_ROLE) {
        require(_price > 0, "Price must be greater than zero");

        uint256 currentId = _nextId++;

        properties[currentId] = Property({
            id: currentId,
            name: _name,
            location: _location,
            description: _description,
            price: _price,
            owner: msg.sender,
            isForSale: true,
            exists: true
        });

        _propertyIds.push(currentId);

        emit PropertyCreated(currentId, _name, _price, msg.sender);
    }

    function buyProperty(uint256 _id) external nonReentrant propertyExists(_id) {
        Property storage prop = properties[_id];

        require(prop.isForSale, "Property is not for sale");
        require(msg.sender != prop.owner, "Owner cannot buy their own property");
        
        uint256 price = prop.price;
        address seller = prop.owner;

        paymentToken.safeTransferFrom(msg.sender, seller, price);

        // Update Ownership
        prop.owner = msg.sender;
        prop.isForSale = false;

        emit PropertyPurchased(_id, msg.sender, seller, price);
    }

    function removeProperty(uint256 _id) external onlyRole(PROPERTY_MANAGER_ROLE) propertyExists(_id) {
        delete properties[_id]; 
        
        for (uint256 i = 0; i < _propertyIds.length; i++) {
            if (_propertyIds[i] == _id) {
                _propertyIds[i] = _propertyIds[_propertyIds.length - 1];
                _propertyIds.pop(); 
                break;
            }
        }

        emit PropertyRemoved(_id);
    }

    function listForSale(uint256 _id, uint256 _newPrice) external onlyPropertyOwner(_id) propertyExists(_id) {
        properties[_id].isForSale = true;
        properties[_id].price = _newPrice;
        emit PropertySaleStatusChanged(_id, true);
        emit PropertyPriceUpdated(_id, _newPrice);
    }

    function delistProperty(uint256 _id) external onlyPropertyOwner(_id) propertyExists(_id) {
        properties[_id].isForSale = false;
        emit PropertySaleStatusChanged(_id, false);
    }

    function getAllProperties() external view returns (Property[] memory) {
        Property[] memory allProps = new Property[](_propertyIds.length);
        
        for (uint256 i = 0; i < _propertyIds.length; i++) {
            allProps[i] = properties[_propertyIds[i]];
        }
        
        return allProps;
    }

    function getProperty(uint256 _id) external view propertyExists(_id) returns (Property memory) {
        return properties[_id];
    }
}
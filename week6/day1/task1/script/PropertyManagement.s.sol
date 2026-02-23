// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {PropertyMarketplace} from "../src/PropertyMarketplace.sol";

contract PropertyMarketplaceScript is Script {
    PropertyMarketplace public propertyMarketplace;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        propertyMarketplace = new PropertyMarketplace(address(0));

        vm.stopBroadcast();
    }
}

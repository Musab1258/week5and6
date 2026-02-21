// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/ERC20.sol";
import "../src/Save.sol";
import "../src/SaveEther.sol";
import "../src/SchoolManagement.sol";
import "../src/Todo.sol";

contract DeployScript is Script {
    ERC20 public erc20Token;
    Save public saveAsset;
    SaveEther public saveEther;
    SchoolManagement public schoolManagement;
    Todo public todo;

    uint8 decimals = 18;
    uint256 initialSupply = 100_000;
    uint256 maxSupply = 200_000;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        deployContracts();

        vm.stopBroadcast();
    }

    function deployContracts() internal {
        erc20Token = new ERC20("Dolapo", "DP", decimals, initialSupply, maxSupply);
        saveAsset = new Save();
        saveEther = new SaveEther();
        schoolManagement = new SchoolManagement(address(erc20Token));
        todo = new Todo();
    }
}
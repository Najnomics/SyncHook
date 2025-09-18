// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console2} from "forge-std/Script.sol";
import {DeployScript} from "./Deploy.s.sol";

contract DeployMainnetScript is DeployScript {
    function run() external override {
        console2.log("Deploying to mainnet...");
        
        // Use mainnet private key if available, otherwise use default
        uint256 privateKey = vm.envOr("MAINNET_PRIVATE_KEY", uint256(0));
        if (privateKey == 0) {
            privateKey = vm.envUint("PRIVATE_KEY");
        }
        
        address deployer = vm.addr(privateKey);
        console2.log("Deploying contracts with account:", deployer);
        console2.log("Account balance:", deployer.balance);
        
        // Additional mainnet safety checks
        require(privateKey != 0, "Mainnet private key not set");
        
        console2.log("WARNING: This will deploy to mainnet!");
        console2.log("Make sure you have reviewed all configurations.");
        
        // Call parent deployment logic
        _deploy();
        
        console2.log("Mainnet deployment completed!");
        console2.log("Contract addresses have been logged above.");
        console2.log("Remember to verify contracts on Etherscan.");
    }
}

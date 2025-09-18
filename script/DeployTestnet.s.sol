// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console2} from "forge-std/Script.sol";
import {DeployScript} from "./Deploy.s.sol";

contract DeployTestnetScript is DeployScript {
    function run() external override {
        console2.log("Deploying to testnet...");
        
        // Use testnet private key if available, otherwise use default
        uint256 privateKey = vm.envOr("TESTNET_PRIVATE_KEY", uint256(0));
        if (privateKey == 0) {
            privateKey = vm.envUint("PRIVATE_KEY");
        }
        
        address deployer = vm.addr(privateKey);
        console2.log("Deploying contracts with account:", deployer);
        console2.log("Account balance:", deployer.balance);
        
        // Call parent deployment logic
        _deploy();
        
        console2.log("Testnet deployment completed!");
        console2.log("Contract addresses have been logged above.");
        console2.log("Remember to verify contracts on block explorer if needed.");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console2} from "forge-std/Script.sol";
import {DeployAnvilScript} from "./DeployAnvil.s.sol";
import {DeployTestnetScript} from "./DeployTestnet.s.sol";
import {DeployMainnetScript} from "./DeployMainnet.s.sol";

contract DeployAllScript is Script {
    function run() external {
        string memory network = vm.envString("NETWORK");
        
        console2.log("Deploying SyncHook to network:", network);
        
        if (keccak256(bytes(network)) == keccak256(bytes("anvil"))) {
            console2.log("Deploying to Anvil...");
            DeployAnvilScript anvilDeploy = new DeployAnvilScript();
            anvilDeploy.run();
        } else if (keccak256(bytes(network)) == keccak256(bytes("testnet"))) {
            console2.log("Deploying to testnet...");
            DeployTestnetScript testnetDeploy = new DeployTestnetScript();
            testnetDeploy.run();
        } else if (keccak256(bytes(network)) == keccak256(bytes("mainnet"))) {
            console2.log("Deploying to mainnet...");
            DeployMainnetScript mainnetDeploy = new DeployMainnetScript();
            mainnetDeploy.run();
        } else {
            revert("Invalid network. Use: anvil, testnet, or mainnet");
        }
        
        console2.log("Deployment completed for network:", network);
    }
}

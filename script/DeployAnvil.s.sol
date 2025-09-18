// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console2} from "forge-std/Script.sol";
import {DeployScript} from "./Deploy.s.sol";
import {SyncHook} from "../src/hooks/SyncHook.sol";
import {SyncAVS} from "../src/avs/SyncAVS.sol";
import {SyncTaskManager} from "../src/avs/SyncTaskManager.sol";
import {StateValidationMiddleware} from "../src/avs/StateValidationMiddleware.sol";
import {AcrossIntegration} from "../src/integration/AcrossIntegration.sol";
import {StateOracles} from "../src/integration/StateOracles.sol";
import {ChainRegistry} from "../src/integration/ChainRegistry.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStateValidation} from "../src/avs/interfaces/IStateValidation.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer/contracts/interfaces/IPermissionController.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {ISyncAVS} from "../src/hooks/interfaces/ISyncAVS.sol";
import {IAcrossIntegration} from "../src/hooks/interfaces/IAcrossIntegration.sol";

contract DeployAnvilScript is DeployScript {
    function run() external override {
        console2.log("Deploying to Anvil local network...");
        console2.log("Using Anvil default account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
        
        // Override private key for Anvil
        uint256 anvilPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(anvilPrivateKey);
        
        console2.log("Deploying contracts with account:", deployer);
        console2.log("Account balance:", deployer.balance);

        vm.startBroadcast(anvilPrivateKey);

        // Deploy StateOracles
        console2.log("Deploying StateOracles...");
        stateOracles = new StateOracles();
        console2.log("StateOracles deployed at:", address(stateOracles));

        // Deploy ChainRegistry
        console2.log("Deploying ChainRegistry...");
        chainRegistry = new ChainRegistry();
        console2.log("ChainRegistry deployed at:", address(chainRegistry));

        // Deploy StateValidationMiddleware
        console2.log("Deploying StateValidationMiddleware...");
        stateValidation = new StateValidationMiddleware(
            address(0), // syncAVS - will be updated later
            address(0), // slashingRegistry
            0.01e18, // validationReward: 0.01 ETH
            0.1e18, // slashingPenalty: 0.1 ETH
            75 // consensusThreshold: 75%
        );
        console2.log("StateValidationMiddleware deployed at:", address(stateValidation));

        // Deploy SyncAVS
        console2.log("Deploying SyncAVS...");
        syncAVS = new SyncAVS(
            IAVSDirectory(address(0)), // avsDirectory
            IRewardsCoordinator(address(0)), // rewardsCoordinator
            ISlashingRegistryCoordinator(address(0)), // registryCoordinator
            IStakeRegistry(address(0)), // stakeRegistry
            IPermissionController(address(0)), // permissionController
            IAllocationManager(address(0)), // allocationManager
            IAcrossIntegration(address(0)) // acrossIntegration - will be updated later
        );
        console2.log("SyncAVS deployed at:", address(syncAVS));

        // Deploy SyncTaskManager
        console2.log("Deploying SyncTaskManager...");
        syncTaskManager = new SyncTaskManager(
            address(syncAVS),
            address(stateValidation),
            0.001e18, // taskCreationFee: 0.001 ETH
            0.005e18, // taskCompletionReward: 0.005 ETH
            0.01e18 // taskFailurePenalty: 0.01 ETH
        );
        console2.log("SyncTaskManager deployed at:", address(syncTaskManager));

        // Deploy AcrossIntegration
        console2.log("Deploying AcrossIntegration...");
        acrossIntegration = new AcrossIntegration(
            ACROSS_SPOKE_POOL,
            address(syncAVS),
            10, // bridgeFeeBps: 0.1%
            1000000e18, // maxRebalancingAmount: 1M tokens
            1000e18, // minRebalancingAmount: 1K tokens
            100 // rebalancingCooldown: 100 blocks
        );
        console2.log("AcrossIntegration deployed at:", address(acrossIntegration));

        // Deploy SyncHook
        console2.log("Deploying SyncHook...");
        syncHook = new SyncHook(
            IPoolManager(address(0)), // poolManager - will be set by Uniswap V4
            ISyncAVS(address(syncAVS)),
            IAcrossIntegration(address(acrossIntegration)),
            address(0) // owner - will be set by deployer
        );
        console2.log("SyncHook deployed at:", address(syncHook));

        // Configure initial settings
        console2.log("Configuring initial settings...");
        _configureInitialSettings();

        vm.stopBroadcast();

        // Log deployment summary
        _logDeploymentSummary();
        
        console2.log("Anvil deployment completed!");
        console2.log("You can now interact with contracts using the addresses above.");
    }
}

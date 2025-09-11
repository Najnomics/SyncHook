// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console2} from "forge-std/Script.sol";
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

contract DeployScript is Script {
    // Core contracts
    SyncHook public syncHook;
    SyncAVS public syncAVS;
    SyncTaskManager public syncTaskManager;
    StateValidationMiddleware public stateValidation;
    AcrossIntegration public acrossIntegration;
    StateOracles public stateOracles;
    ChainRegistry public chainRegistry;

    // Configuration
    address public constant USDC = 0xA0B86A33e6441b8C4c8C0e1234567890AbcdEF12; // Example address
    address public constant WETH = 0x1234567890123456789012345678901234567890; // Example address
    address public constant ACROSS_SPOKE_POOL = 0x1234567890123456789012345678901234567890; // Example address
    address public constant ACROSS_RELAYER = 0x1234567890123456789012345678901234567890; // Example address

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deploying contracts with account:", deployer);
        console2.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

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

        // Update StateValidationMiddleware with SyncAVS address
        console2.log("Updating StateValidationMiddleware with SyncAVS address...");
        stateValidation = new StateValidationMiddleware(
            address(syncAVS),
            address(0), // slashingRegistry
            0.01e18, // validationReward: 0.01 ETH
            0.1e18, // slashingPenalty: 0.1 ETH
            75 // consensusThreshold: 75%
        );
        console2.log("StateValidationMiddleware updated at:", address(stateValidation));

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
    }

    function _configureInitialSettings() internal {
        // Configure ChainRegistry with initial chains
        chainRegistry.addChain(1, "Ethereum", 0x1234567890123456789012345678901234567890, 20000000000, 12); // Ethereum
        chainRegistry.addChain(137, "Polygon", 0x1234567890123456789012345678901234567890, 30000000000, 2); // Polygon
        chainRegistry.addChain(42161, "Arbitrum", 0x1234567890123456789012345678901234567890, 1000000000, 1); // Arbitrum

        // Configure StateOracles with initial price feeds
        stateOracles.authorizeOracle(0x1234567890123456789012345678901234567890);
        stateOracles.addOracle(USDC, 0x1234567890123456789012345678901234567890, 1e18, 8); // USDC price feed
        stateOracles.addOracle(WETH, 0x1234567890123456789012345678901234567890, 1e18, 8); // WETH price feed

        // Set initial validation criteria
        stateValidation.updateValidationCriteria(
            IStateValidation.ValidationCriteria({
                maxPriceDeviation: 0.05e18, // 5%
                maxLiquidityChange: 0.1e18, // 10%
                maxTimeGap: 300, // 5 minutes
                minimumConfirmations: 3
            })
        );
    }

    function _logDeploymentSummary() internal view {
        console2.log("\n=== DEPLOYMENT SUMMARY ===");
        console2.log("SyncHook:", address(syncHook));
        console2.log("SyncAVS:", address(syncAVS));
        console2.log("SyncTaskManager:", address(syncTaskManager));
        console2.log("StateValidationMiddleware:", address(stateValidation));
        console2.log("AcrossIntegration:", address(acrossIntegration));
        console2.log("StateOracles:", address(stateOracles));
        console2.log("ChainRegistry:", address(chainRegistry));
        console2.log("========================\n");
    }
}

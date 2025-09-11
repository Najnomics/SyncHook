// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console2} from "forge-std/Script.sol";
import {SyncAVS} from "../src/avs/SyncAVS.sol";
import {SyncTaskManager} from "../src/avs/SyncTaskManager.sol";
import {StateValidationMiddleware} from "../src/avs/StateValidationMiddleware.sol";
import {IStateValidation} from "../src/avs/interfaces/IStateValidation.sol";

contract SetupAVSScript is Script {
    // Contract addresses (will be set via environment variables)
    address public syncAVS;
    address public syncTaskManager;
    address public stateValidation;

    // Configuration
    uint256 public constant MINIMUM_STAKE = 1e18; // 1 ETH
    uint256 public constant SLASHING_THRESHOLD = 0.1e18; // 10%
    uint256 public constant REWARD_RATE = 0.05e18; // 5% annual reward rate

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get contract addresses from environment variables
        syncAVS = vm.envAddress("SYNC_AVS_ADDRESS");
        syncTaskManager = vm.envAddress("SYNC_TASK_MANAGER_ADDRESS");
        stateValidation = vm.envAddress("STATE_VALIDATION_ADDRESS");

        console2.log("Setting up AVS with account:", deployer);
        console2.log("SyncAVS address:", syncAVS);
        console2.log("SyncTaskManager address:", syncTaskManager);
        console2.log("StateValidation address:", stateValidation);

        vm.startBroadcast(deployerPrivateKey);

        // Setup SyncAVS
        console2.log("Setting up SyncAVS...");
        _setupSyncAVS();

        // Setup SyncTaskManager
        console2.log("Setting up SyncTaskManager...");
        _setupSyncTaskManager();

        // Setup StateValidationMiddleware
        console2.log("Setting up StateValidationMiddleware...");
        _setupStateValidation();

        vm.stopBroadcast();

        console2.log("AVS setup completed successfully!");
    }

    function _setupSyncAVS() internal {
        SyncAVS avs = SyncAVS(syncAVS);

        // Update slashing parameters
        avs.updateSlashingParameters(SLASHING_THRESHOLD, MINIMUM_STAKE);
        console2.log("Updated slashing parameters - threshold:", SLASHING_THRESHOLD, "min stake:", MINIMUM_STAKE);

        // Register a test operator
        avs.registerOperator(address(0x1234567890123456789012345678901234567890), "test-operator-metadata");
        console2.log("Registered test operator");

        // Submit a test state update
        avs.submitStateUpdate(
            1, // chainId: Ethereum
            SyncAVS.PoolState({
                totalLiquidity: 1000000e18,
                price: 2000e18,
                volume24h: 100000e18,
                fees24h: 1000e18,
                timestamp: block.timestamp,
                blockNumber: block.number
            }),
            "" // signature: empty for test
        );
        console2.log("Submitted test state update");
    }

    function _setupSyncTaskManager() internal {
        SyncTaskManager taskManager = SyncTaskManager(syncTaskManager);

        // Update task configuration
        taskManager.updateTaskConfig(
            0.001e18, // taskCreationFee: 0.001 ETH
            0.005e18, // taskCompletionReward: 0.005 ETH
            0.01e18   // taskFailurePenalty: 0.01 ETH
        );
        console2.log("Updated task configuration");

        // Create a test task
        taskManager.createTask{value: 0.001e18}(
            1, // taskType: StateUpdate
            SyncTaskManager.TaskPriority.Medium, // priority
            1, // chainId: Ethereum
            bytes32(0), // poolId: placeholder
            "", // payload: empty
            3600 // timeout: 1 hour
        );
        console2.log("Created test task");
    }

    function _setupStateValidation() internal {
        StateValidationMiddleware validation = StateValidationMiddleware(stateValidation);

        // Update validation criteria
        validation.updateValidationCriteria(
            IStateValidation.ValidationCriteria({
                maxPriceDeviation: 0.05e18, // 5%
                maxLiquidityChange: 0.1e18, // 10%
                maxTimeGap: 300, // 5 minutes
                minimumConfirmations: 3
            })
        );
        console2.log("Updated validation criteria");

        // Validate a test operator signature
        validation.validateOperatorSignature(
            address(0x1234567890123456789012345678901234567890),
            bytes32(0), // messageHash: placeholder
            "" // signature: empty for test
        );
        console2.log("Validated test operator signature");
    }
}

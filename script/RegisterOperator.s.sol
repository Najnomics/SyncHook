// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console2} from "forge-std/Script.sol";
import {SyncAVS} from "../src/avs/SyncAVS.sol";
import {SyncTaskManager} from "../src/avs/SyncTaskManager.sol";
import {StateValidationMiddleware} from "../src/avs/StateValidationMiddleware.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RegisterOperatorScript is Script {
    // Contract addresses (will be set via environment variables)
    address public syncAVS;
    address public syncTaskManager;
    address public stateValidation;

    // Operator configuration
    address public operator;
    string public metadataURI;
    uint256 public stakeAmount;
    address public stakeToken; // ETH or ERC20 token address

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get configuration from environment variables
        syncAVS = vm.envAddress("SYNC_AVS_ADDRESS");
        syncTaskManager = vm.envAddress("SYNC_TASK_MANAGER_ADDRESS");
        stateValidation = vm.envAddress("STATE_VALIDATION_ADDRESS");
        operator = vm.envAddress("OPERATOR_ADDRESS");
        metadataURI = vm.envString("OPERATOR_METADATA_URI");
        stakeAmount = vm.envUint("STAKE_AMOUNT");
        stakeToken = vm.envAddress("STAKE_TOKEN_ADDRESS");

        console2.log("Registering operator with account:", deployer);
        console2.log("Operator address:", operator);
        console2.log("Metadata URI:", metadataURI);
        console2.log("Stake amount:", stakeAmount);
        console2.log("Stake token:", stakeToken);

        vm.startBroadcast(deployerPrivateKey);

        // Register operator
        console2.log("Registering operator...");
        _registerOperator();

        // Setup operator permissions
        console2.log("Setting up operator permissions...");
        _setupOperatorPermissions();

        // Initialize operator stake
        console2.log("Initializing operator stake...");
        _initializeOperatorStake();

        vm.stopBroadcast();

        console2.log("Operator registration completed successfully!");
    }

    function _registerOperator() internal {
        SyncAVS avs = SyncAVS(syncAVS);

        // Register the operator
        avs.registerOperator(operator, metadataURI);
        console2.log("Operator registered with metadata URI:", metadataURI);

        // Verify registration
        bool isRegistered = avs.isRegisteredOperator(operator);
        require(isRegistered, "Operator registration failed");
        console2.log("Operator registration verified");
    }

    function _setupOperatorPermissions() internal {
        SyncTaskManager taskManager = SyncTaskManager(syncTaskManager);

        // Update task configuration
        taskManager.updateTaskConfig(
            0.001e18, // taskCreationFee: 0.001 ETH
            0.005e18, // taskCompletionReward: 0.005 ETH
            0.01e18   // taskFailurePenalty: 0.01 ETH
        );
        console2.log("Task configuration updated");

        // Create a test task for the operator
        taskManager.createTask{value: 0.001e18}(
            1, // taskType: StateUpdate
            SyncTaskManager.TaskPriority.Medium, // priority
            1, // chainId: Ethereum
            bytes32(0), // poolId: placeholder
            "", // payload: empty
            3600 // timeout: 1 hour
        );
        console2.log("Test task created for operator");
    }

    function _initializeOperatorStake() internal {
        SyncAVS avs = SyncAVS(syncAVS);

        // For now, just verify the operator is registered
        // In a real implementation, staking would be handled by EigenLayer
        bool isRegistered = avs.isRegisteredOperator(operator);
        require(isRegistered, "Operator not registered");
        console2.log("Operator registration verified for staking");

        // In a real implementation, you would:
        // 1. Call EigenLayer's delegation functions
        // 2. Set up operator permissions
        // 3. Configure slashing parameters
        
        console2.log("Stake initialization completed (placeholder)");
    }
}

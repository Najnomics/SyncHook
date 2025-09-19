// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IAVSTaskHook} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSTaskHook.sol";
import {ITaskMailboxTypes} from "@eigenlayer-contracts/src/contracts/interfaces/ITaskMailbox.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title AVSTaskHook
 * @dev SyncHook AVS Task Hook for EigenLayer integration
 * This contract handles task validation and processing for SyncHook cross-chain operations
 */
contract AVSTaskHook is IAVSTaskHook, Ownable, Pausable {
    // Task types
    enum TaskType {
        StateUpdate,
        Rebalancing,
        CrossChainSync,
        Validation
    }
    
    // Task configuration
    struct TaskConfig {
        uint96 baseFee;
        uint96 maxFee;
        uint32 timeout;
        bool enabled;
    }
    
    // Task validation rules
    struct ValidationRules {
        uint256 maxPriceDeviation;
        uint256 maxLiquidityChange;
        uint256 maxTimeGap;
        uint32 minimumConfirmations;
    }
    
    // State
    mapping(TaskType => TaskConfig) public taskConfigs;
    ValidationRules public validationRules;
    mapping(bytes32 => bool) public processedTasks;
    
    // Events
    event TaskConfigUpdated(TaskType indexed taskType, uint96 baseFee, uint96 maxFee, uint32 timeout);
    event ValidationRulesUpdated(uint256 maxPriceDeviation, uint256 maxLiquidityChange, uint256 maxTimeGap, uint32 minimumConfirmations);
    event TaskProcessed(bytes32 indexed taskHash, TaskType taskType, bool success);
    
    constructor() Ownable(msg.sender) {
        // Initialize task configurations
        taskConfigs[TaskType.StateUpdate] = TaskConfig({
            baseFee: 0.001 ether,
            maxFee: 0.01 ether,
            timeout: 300, // 5 minutes
            enabled: true
        });
        
        taskConfigs[TaskType.Rebalancing] = TaskConfig({
            baseFee: 0.005 ether,
            maxFee: 0.05 ether,
            timeout: 600, // 10 minutes
            enabled: true
        });
        
        taskConfigs[TaskType.CrossChainSync] = TaskConfig({
            baseFee: 0.01 ether,
            maxFee: 0.1 ether,
            timeout: 1800, // 30 minutes
            enabled: true
        });
        
        taskConfigs[TaskType.Validation] = TaskConfig({
            baseFee: 0.0005 ether,
            maxFee: 0.005 ether,
            timeout: 120, // 2 minutes
            enabled: true
        });
        
        // Initialize validation rules
        validationRules = ValidationRules({
            maxPriceDeviation: 0.05e18, // 5%
            maxLiquidityChange: 0.1e18, // 10%
            maxTimeGap: 300, // 5 minutes
            minimumConfirmations: 3
        });
    }
    
    function validatePreTaskCreation(
        address caller,
        ITaskMailboxTypes.TaskParams memory taskParams
    ) external view override {
        require(!paused(), "AVSTaskHook: contract is paused");
        
        // Decode task type from taskParams
        TaskType taskType = _decodeTaskType(taskParams.taskData);
        require(taskConfigs[taskType].enabled, "AVSTaskHook: task type disabled");
        
        // Validate caller authorization
        require(caller != address(0), "AVSTaskHook: invalid caller");
        
        // Validate task data
        _validateTaskData(taskType, taskParams.taskData);
    }

    function handlePostTaskCreation(
        bytes32 taskHash
    ) external override {
        require(!paused(), "AVSTaskHook: contract is paused");
        
        // Log task creation
        TaskType taskType = _decodeTaskTypeFromHash(taskHash);
        emit TaskProcessed(taskHash, taskType, true);
    }

    function validatePreTaskResultSubmission(
        address caller,
        bytes32 taskHash,
        bytes memory cert,
        bytes memory result
    ) external view override {
        require(!paused(), "AVSTaskHook: contract is paused");
        require(caller != address(0), "AVSTaskHook: invalid caller");
        require(cert.length > 0, "AVSTaskHook: invalid certificate");
        require(result.length > 0, "AVSTaskHook: invalid result");
        
        // Validate task hasn't been processed before
        require(!processedTasks[taskHash], "AVSTaskHook: task already processed");
        
        // Validate result format
        _validateTaskResult(taskHash, result);
    }

    function handlePostTaskResultSubmission(
        address caller,
        bytes32 taskHash
    ) external override {
        require(!paused(), "AVSTaskHook: contract is paused");
        
        // Mark task as processed
        processedTasks[taskHash] = true;
        
        // Log task completion
        TaskType taskType = _decodeTaskTypeFromHash(taskHash);
        emit TaskProcessed(taskHash, taskType, true);
    }

    function calculateTaskFee(
        ITaskMailboxTypes.TaskParams memory taskParams
    ) external view override returns (uint96) {
        TaskType taskType = _decodeTaskType(taskParams.taskData);
        TaskConfig memory config = taskConfigs[taskType];
        
        require(config.enabled, "AVSTaskHook: task type disabled");
        
        // Calculate fee based on task complexity and gas price
        uint96 fee = config.baseFee;
        
        // Add complexity-based fee
        if (taskType == TaskType.CrossChainSync) {
            fee += uint96(config.baseFee / 2); // 50% additional for cross-chain
        } else if (taskType == TaskType.Rebalancing) {
            fee += uint96(config.baseFee / 4); // 25% additional for rebalancing
        }
        
        // Ensure fee doesn't exceed maximum
        if (fee > config.maxFee) {
            fee = config.maxFee;
        }
        
        return fee;
    }
    
    // Admin functions
    function updateTaskConfig(
        TaskType taskType,
        uint96 baseFee,
        uint96 maxFee,
        uint32 timeout,
        bool enabled
    ) external onlyOwner {
        taskConfigs[taskType] = TaskConfig({
            baseFee: baseFee,
            maxFee: maxFee,
            timeout: timeout,
            enabled: enabled
        });
        
        emit TaskConfigUpdated(taskType, baseFee, maxFee, timeout);
    }
    
    function updateValidationRules(
        uint256 maxPriceDeviation,
        uint256 maxLiquidityChange,
        uint256 maxTimeGap,
        uint32 minimumConfirmations
    ) external onlyOwner {
        validationRules = ValidationRules({
            maxPriceDeviation: maxPriceDeviation,
            maxLiquidityChange: maxLiquidityChange,
            maxTimeGap: maxTimeGap,
            minimumConfirmations: minimumConfirmations
        });
        
        emit ValidationRulesUpdated(maxPriceDeviation, maxLiquidityChange, maxTimeGap, minimumConfirmations);
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // Internal functions
    function _decodeTaskType(bytes memory taskData) internal pure returns (TaskType) {
        if (taskData.length < 1) return TaskType.StateUpdate;
        
        uint8 taskTypeByte = uint8(taskData[0]);
        if (taskTypeByte >= uint8(TaskType.Validation) + 1) {
            return TaskType.StateUpdate; // Default fallback
        }
        
        return TaskType(taskTypeByte);
    }
    
    function _decodeTaskTypeFromHash(bytes32 taskHash) internal pure returns (TaskType) {
        // This is a simplified implementation
        // In practice, you would decode from the actual task data
        return TaskType.StateUpdate;
    }
    
    function _validateTaskData(TaskType taskType, bytes memory taskData) internal view {
        require(taskData.length > 0, "AVSTaskHook: empty task data");
        
        // Basic validation based on task type
        if (taskType == TaskType.StateUpdate) {
            require(taskData.length >= 32, "AVSTaskHook: invalid state update data");
        } else if (taskType == TaskType.Rebalancing) {
            require(taskData.length >= 64, "AVSTaskHook: invalid rebalancing data");
        } else if (taskType == TaskType.CrossChainSync) {
            require(taskData.length >= 96, "AVSTaskHook: invalid cross-chain sync data");
        }
    }
    
    function _validateTaskResult(bytes32 taskHash, bytes memory result) internal view {
        require(result.length > 0, "AVSTaskHook: empty result");
        
        // Basic result validation
        // In practice, you would validate the result format based on task type
        require(result.length >= 32, "AVSTaskHook: invalid result format");
    }
}

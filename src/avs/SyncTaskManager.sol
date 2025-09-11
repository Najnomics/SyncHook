// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ISyncAVS} from "./interfaces/ISyncAVS.sol";
import {IStateValidation} from "./interfaces/IStateValidation.sol";
import {StateAggregation} from "./libraries/StateAggregation.sol";
import {PredictiveAnalytics} from "./libraries/PredictiveAnalytics.sol";

/**
 * @title SyncTaskManager
 * @notice Task coordination and management for the SyncAVS system
 * @dev Manages task creation, assignment, validation, and completion
 */
contract SyncTaskManager is Ownable, Pausable, ReentrancyGuard {
    using StateAggregation for StateAggregation.ChainState;
    using StateAggregation for StateAggregation.AggregatedState;
    using PredictiveAnalytics for PredictiveAnalytics.PredictionResult;

    /// @notice Maximum number of active tasks per operator
    uint256 public constant MAX_TASKS_PER_OPERATOR = 10;
    
    /// @notice Maximum task timeout (24 hours in blocks)
    uint256 public constant MAX_TASK_TIMEOUT = 7200; // 24 hours at 12s blocks
    
    /// @notice Minimum task timeout (1 hour in blocks)
    uint256 public constant MIN_TASK_TIMEOUT = 300; // 1 hour at 12s blocks
    
    /// @notice Task priority levels
    enum TaskPriority { Low, Medium, High, Critical }
    
    /// @notice Task status
    enum TaskStatus { Pending, Assigned, InProgress, Completed, Failed, Cancelled, Timeout }

    /**
     * @notice Task structure
     * @param taskId Unique task identifier
     * @param taskType Type of task (1 = state update, 2 = rebalancing, 3 = validation)
     * @param priority Task priority level
     * @param assignedOperator Operator assigned to the task
     * @param chainId Target chain ID
     * @param poolId Pool identifier
     * @param payload Task-specific data
     * @param deadline Task deadline (block number)
     * @param status Current task status
     * @param createdAt Task creation timestamp
     * @param updatedAt Last update timestamp
     * @param result Task result data
     * @param reward Task completion reward
     * @param penalty Task failure penalty
     */
    struct Task {
        uint256 taskId;
        uint256 taskType;
        TaskPriority priority;
        address assignedOperator;
        uint256 chainId;
        bytes32 poolId;
        bytes payload;
        uint256 deadline;
        TaskStatus status;
        uint256 createdAt;
        uint256 updatedAt;
        bytes result;
        uint256 reward;
        uint256 penalty;
    }

    /// @notice Mapping of task ID to task details
    mapping(uint256 => Task) public tasks;
    
    /// @notice Mapping of operator to active task count
    mapping(address => uint256) public operatorTaskCount;
    
    /// @notice Mapping of operator to task list
    mapping(address => uint256[]) public operatorTasks;
    
    /// @notice Mapping of chain ID to pending tasks
    mapping(uint256 => uint256[]) public chainTasks;
    
    /// @notice Mapping of task type to pending tasks
    mapping(uint256 => uint256[]) public typeTasks;
    
    /// @notice Array of all task IDs
    uint256[] public allTasks;
    
    /// @notice Task counter
    uint256 public taskCounter;
    
    /// @notice SyncAVS contract reference
    address public immutable syncAVS;
    
    /// @notice State validation contract reference
    address public immutable stateValidation;
    
    /// @notice Task creation fee
    uint256 public taskCreationFee;
    
    /// @notice Task completion reward
    uint256 public taskCompletionReward;
    
    /// @notice Task failure penalty
    uint256 public taskFailurePenalty;
    
    /// @notice Emergency pause for task creation
    bool public taskCreationPaused;

    /**
     * @notice Constructor
     * @param _syncAVS SyncAVS contract address
     * @param _stateValidation State validation contract address
     * @param _taskCreationFee Task creation fee
     * @param _taskCompletionReward Task completion reward
     * @param _taskFailurePenalty Task failure penalty
     */
    constructor(
        address _syncAVS,
        address _stateValidation,
        uint256 _taskCreationFee,
        uint256 _taskCompletionReward,
        uint256 _taskFailurePenalty
    ) Ownable(msg.sender) {
        require(_syncAVS != address(0), "Invalid SyncAVS address");
        require(_stateValidation != address(0), "Invalid state validation address");
        
        syncAVS = _syncAVS;
        stateValidation = _stateValidation;
        taskCreationFee = _taskCreationFee;
        taskCompletionReward = _taskCompletionReward;
        taskFailurePenalty = _taskFailurePenalty;
    }

    /**
     * @notice Create a new task
     * @param taskType Type of task
     * @param priority Task priority
     * @param chainId Target chain ID
     * @param poolId Pool identifier
     * @param payload Task-specific data
     * @param timeout Task timeout in blocks
     * @return taskId Created task ID
     */
    function createTask(
        uint256 taskType,
        TaskPriority priority,
        uint256 chainId,
        bytes32 poolId,
        bytes calldata payload,
        uint256 timeout
    ) external payable nonReentrant returns (uint256 taskId) {
        require(!taskCreationPaused, "Task creation paused");
        require(msg.value >= taskCreationFee, "Insufficient creation fee");
        require(taskType >= 1 && taskType <= 3, "Invalid task type");
        require(timeout >= MIN_TASK_TIMEOUT && timeout <= MAX_TASK_TIMEOUT, "Invalid timeout");
        require(payload.length > 0, "Empty payload");
        
        taskId = ++taskCounter;
        
        Task memory newTask = Task({
            taskId: taskId,
            taskType: taskType,
            priority: priority,
            assignedOperator: address(0),
            chainId: chainId,
            poolId: poolId,
            payload: payload,
            deadline: block.number + timeout,
            status: TaskStatus.Pending,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            result: "",
            reward: taskCompletionReward,
            penalty: taskFailurePenalty
        });
        
        tasks[taskId] = newTask;
        allTasks.push(taskId);
        chainTasks[chainId].push(taskId);
        typeTasks[taskType].push(taskId);
        
        emit TaskCreated(taskId, taskType, priority, chainId, poolId, timeout);
    }

    /**
     * @notice Assign a task to an operator
     * @param taskId Task identifier
     * @param operator Operator address
     */
    function assignTask(uint256 taskId, address operator) external onlyOwner {
        require(tasks[taskId].taskId != 0, "Task not found");
        require(tasks[taskId].status == TaskStatus.Pending, "Task not pending");
        require(operator != address(0), "Invalid operator");
        require(operatorTaskCount[operator] < MAX_TASKS_PER_OPERATOR, "Operator at capacity");
        
        tasks[taskId].assignedOperator = operator;
        tasks[taskId].status = TaskStatus.Assigned;
        tasks[taskId].updatedAt = block.timestamp;
        
        operatorTaskCount[operator]++;
        operatorTasks[operator].push(taskId);
        
        emit TaskAssigned(taskId, operator);
    }

    /**
     * @notice Start working on a task
     * @param taskId Task identifier
     */
    function startTask(uint256 taskId) external {
        require(tasks[taskId].taskId != 0, "Task not found");
        require(tasks[taskId].assignedOperator == msg.sender, "Not assigned operator");
        require(tasks[taskId].status == TaskStatus.Assigned, "Task not assigned");
        require(block.number <= tasks[taskId].deadline, "Task deadline passed");
        
        tasks[taskId].status = TaskStatus.InProgress;
        tasks[taskId].updatedAt = block.timestamp;
        
        emit TaskStarted(taskId, msg.sender);
    }

    /**
     * @notice Complete a task
     * @param taskId Task identifier
     * @param result Task result data
     */
    function completeTask(uint256 taskId, bytes calldata result) external {
        require(tasks[taskId].taskId != 0, "Task not found");
        require(tasks[taskId].assignedOperator == msg.sender, "Not assigned operator");
        require(tasks[taskId].status == TaskStatus.InProgress, "Task not in progress");
        require(block.number <= tasks[taskId].deadline, "Task deadline passed");
        require(result.length > 0, "Empty result");
        
        // Validate task result
        require(_validateTaskResult(taskId, result), "Invalid task result");
        
        tasks[taskId].status = TaskStatus.Completed;
        tasks[taskId].result = result;
        tasks[taskId].updatedAt = block.timestamp;
        
        // Process task completion
        _processTaskCompletion(taskId);
        
        emit TaskCompleted(taskId, msg.sender, result);
    }

    /**
     * @notice Fail a task
     * @param taskId Task identifier
     * @param reason Failure reason
     */
    function failTask(uint256 taskId, string calldata reason) external {
        require(tasks[taskId].taskId != 0, "Task not found");
        require(tasks[taskId].assignedOperator == msg.sender, "Not assigned operator");
        require(tasks[taskId].status == TaskStatus.InProgress, "Task not in progress");
        
        tasks[taskId].status = TaskStatus.Failed;
        tasks[taskId].updatedAt = block.timestamp;
        
        // Process task failure
        _processTaskFailure(taskId);
        
        emit TaskFailed(taskId, msg.sender, reason);
    }

    /**
     * @notice Cancel a task
     * @param taskId Task identifier
     * @param reason Cancellation reason
     */
    function cancelTask(uint256 taskId, string calldata reason) external onlyOwner {
        require(tasks[taskId].taskId != 0, "Task not found");
        require(tasks[taskId].status != TaskStatus.Completed, "Cannot cancel completed task");
        
        TaskStatus oldStatus = tasks[taskId].status;
        tasks[taskId].status = TaskStatus.Cancelled;
        tasks[taskId].updatedAt = block.timestamp;
        
        // Update operator task count if task was assigned
        if (oldStatus == TaskStatus.Assigned || oldStatus == TaskStatus.InProgress) {
            address operator = tasks[taskId].assignedOperator;
            if (operator != address(0)) {
                operatorTaskCount[operator]--;
            }
        }
        
        emit TaskCancelled(taskId, reason);
    }

    /**
     * @notice Check for timed out tasks
     * @param taskIds Array of task IDs to check
     */
    function checkTimeouts(uint256[] calldata taskIds) external {
        for (uint256 i = 0; i < taskIds.length; i++) {
            uint256 taskId = taskIds[i];
            Task storage task = tasks[taskId];
            
            if (task.taskId != 0 && 
                (task.status == TaskStatus.Assigned || task.status == TaskStatus.InProgress) &&
                block.number > task.deadline) {
                
                task.status = TaskStatus.Timeout;
                task.updatedAt = block.timestamp;
                
                // Update operator task count
                if (task.assignedOperator != address(0)) {
                    operatorTaskCount[task.assignedOperator]--;
                }
                
                emit TaskTimeout(taskId, task.assignedOperator);
            }
        }
    }

    /**
     * @notice Get task details
     * @param taskId Task identifier
     * @return task Task details
     */
    function getTask(uint256 taskId) external view returns (Task memory task) {
        return tasks[taskId];
    }

    /**
     * @notice Get tasks for an operator
     * @param operator Operator address
     * @return taskIds Array of task IDs
     */
    function getOperatorTasks(address operator) external view returns (uint256[] memory taskIds) {
        return operatorTasks[operator];
    }

    /**
     * @notice Get tasks for a chain
     * @param chainId Chain identifier
     * @return taskIds Array of task IDs
     */
    function getChainTasks(uint256 chainId) external view returns (uint256[] memory taskIds) {
        return chainTasks[chainId];
    }

    /**
     * @notice Get tasks by type
     * @param taskType Task type
     * @return taskIds Array of task IDs
     */
    function getTasksByType(uint256 taskType) external view returns (uint256[] memory taskIds) {
        return typeTasks[taskType];
    }

    /**
     * @notice Get all tasks
     * @return taskIds Array of all task IDs
     */
    function getAllTasks() external view returns (uint256[] memory taskIds) {
        return allTasks;
    }

    /**
     * @notice Get task statistics
     * @return totalTasks Total number of tasks
     * @return pendingTasks Number of pending tasks
     * @return inProgressTasks Number of in-progress tasks
     * @return completedTasks Number of completed tasks
     * @return failedTasks Number of failed tasks
     */
    function getTaskStatistics() external view returns (
        uint256 totalTasks,
        uint256 pendingTasks,
        uint256 inProgressTasks,
        uint256 completedTasks,
        uint256 failedTasks
    ) {
        totalTasks = allTasks.length;
        
        for (uint256 i = 0; i < allTasks.length; i++) {
            TaskStatus status = tasks[allTasks[i]].status;
            
            if (status == TaskStatus.Pending) {
                pendingTasks++;
            } else if (status == TaskStatus.InProgress) {
                inProgressTasks++;
            } else if (status == TaskStatus.Completed) {
                completedTasks++;
            } else if (status == TaskStatus.Failed) {
                failedTasks++;
            }
        }
    }

    /**
     * @notice Update task configuration
     * @param _taskCreationFee New task creation fee
     * @param _taskCompletionReward New task completion reward
     * @param _taskFailurePenalty New task failure penalty
     */
    function updateTaskConfig(
        uint256 _taskCreationFee,
        uint256 _taskCompletionReward,
        uint256 _taskFailurePenalty
    ) external onlyOwner {
        taskCreationFee = _taskCreationFee;
        taskCompletionReward = _taskCompletionReward;
        taskFailurePenalty = _taskFailurePenalty;
        
        emit TaskConfigUpdated(_taskCreationFee, _taskCompletionReward, _taskFailurePenalty);
    }

    /**
     * @notice Pause task creation
     */
    function pauseTaskCreation() external onlyOwner {
        taskCreationPaused = true;
        emit TaskCreationPaused();
    }

    /**
     * @notice Resume task creation
     */
    function resumeTaskCreation() external onlyOwner {
        taskCreationPaused = false;
        emit TaskCreationResumed();
    }

    /**
     * @notice Emergency pause
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Emergency unpause
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ Internal Functions ============

    /**
     * @notice Validate task result
     * @param taskId Task identifier
     * @param result Task result data
     * @return isValid True if result is valid
     */
    function _validateTaskResult(uint256 taskId, bytes calldata result) internal view returns (bool isValid) {
        Task memory task = tasks[taskId];
        
        // Basic validation - in reality would use more sophisticated validation
        if (task.taskType == 1) { // State update task
            // Validate state update format
            return result.length >= 32; // Minimum data length
        } else if (task.taskType == 2) { // Rebalancing task
            // Validate rebalancing result
            return result.length >= 64; // Minimum data length
        } else if (task.taskType == 3) { // Validation task
            // Validate validation result
            return result.length >= 16; // Minimum data length
        }
        
        return false;
    }

    /**
     * @notice Process task completion
     * @param taskId Task identifier
     */
    function _processTaskCompletion(uint256 taskId) internal {
        Task storage task = tasks[taskId];
        
        // Update operator task count
        if (task.assignedOperator != address(0)) {
            operatorTaskCount[task.assignedOperator]--;
        }
        
        // Process task-specific completion logic
        if (task.taskType == 1) { // State update
            _processStateUpdateCompletion(taskId);
        } else if (task.taskType == 2) { // Rebalancing
            _processRebalancingCompletion(taskId);
        } else if (task.taskType == 3) { // Validation
            _processValidationCompletion(taskId);
        }
    }

    /**
     * @notice Process task failure
     * @param taskId Task identifier
     */
    function _processTaskFailure(uint256 taskId) internal {
        Task storage task = tasks[taskId];
        
        // Update operator task count
        if (task.assignedOperator != address(0)) {
            operatorTaskCount[task.assignedOperator]--;
        }
        
        // Process failure penalties
        // In reality, this would implement slashing mechanisms
    }

    /**
     * @notice Process state update completion
     * @param taskId Task identifier
     */
    function _processStateUpdateCompletion(uint256 taskId) internal {
        // Notify SyncAVS of state update completion
        // This would call SyncAVS.updateStateFromTask(taskId, tasks[taskId].result)
    }

    /**
     * @notice Process rebalancing completion
     * @param taskId Task identifier
     */
    function _processRebalancingCompletion(uint256 taskId) internal {
        // Notify Across integration of rebalancing completion
        // This would call AcrossIntegration.processRebalancingResult(taskId, tasks[taskId].result)
    }

    /**
     * @notice Process validation completion
     * @param taskId Task identifier
     */
    function _processValidationCompletion(uint256 taskId) internal {
        // Notify state validation of validation completion
        // This would call StateValidation.processValidationResult(taskId, tasks[taskId].result)
    }

    // ============ Events ============

    event TaskCreated(uint256 indexed taskId, uint256 taskType, TaskPriority priority, uint256 chainId, bytes32 poolId, uint256 timeout);
    event TaskAssigned(uint256 indexed taskId, address indexed operator);
    event TaskStarted(uint256 indexed taskId, address indexed operator);
    event TaskCompleted(uint256 indexed taskId, address indexed operator, bytes result);
    event TaskFailed(uint256 indexed taskId, address indexed operator, string reason);
    event TaskCancelled(uint256 indexed taskId, string reason);
    event TaskTimeout(uint256 indexed taskId, address indexed operator);
    event TaskConfigUpdated(uint256 taskCreationFee, uint256 taskCompletionReward, uint256 taskFailurePenalty);
    event TaskCreationPaused();
    event TaskCreationResumed();
}

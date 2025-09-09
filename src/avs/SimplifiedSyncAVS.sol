// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title SimplifiedSyncAVS
 * @author SyncHook Team
 * @notice Simplified version of SyncAVS for testing and development
 * @dev This version removes EigenLayer dependencies to focus on core logic testing
 */

import {ISyncAVS} from "./interfaces/ISyncAVS.sol";
import {IStateValidation} from "./interfaces/IStateValidation.sol";
import {Constants} from "../utils/Constants.sol";
import {Events} from "../utils/Events.sol";
import {Errors} from "../utils/Errors.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SimplifiedSyncAVS is ISyncAVS, Ownable, Pausable, ReentrancyGuard {
    
    IStateValidation public immutable stateValidation;
    
    uint32 public latestTaskNum;
    
    mapping(uint32 => TaskMetadata) public taskMetadata;
    mapping(uint32 => StateUpdateTask) public stateUpdateTasks;
    mapping(bytes32 => RebalancingTask) public rebalancingTasks;
    mapping(address => OperatorInfo) public operatorInfo;
    mapping(bytes32 => mapping(uint256 => PoolState)) private chainStates;
    mapping(bytes32 => AggregatedMetrics) private aggregatedMetrics;
    mapping(uint32 => mapping(address => bool)) public taskResponses;
    
    uint256 public slashingPenaltyRate = Constants.SLASHING_PENALTY_RATE;
    uint256 public maxSlashingPenalty = Constants.MAX_SLASHING_PENALTY;
    uint256 public minimumStakeRequired = Constants.OPERATOR_STAKE_MINIMUM;
    uint256 public taskResponseWindow = Constants.TASK_RESPONSE_WINDOW;
    
    modifier onlyRegisteredOperator() {
        if (!operatorInfo[msg.sender].isRegistered) {
            revert Errors.InvalidOperator(msg.sender);
        }
        _;
    }
    
    function checkNotPaused() internal view {
        if (paused()) revert Errors.EmergencyPaused();
    }
    
    constructor(
        address _stateValidation,
        address _owner
    ) Ownable(_owner) {
        stateValidation = IStateValidation(_stateValidation);
    }
    
    function createStateUpdateTask(
        uint256 chainId,
        bytes32 poolId,
        PoolState calldata poolState
    ) external override returns (uint32 taskIndex) {
        checkNotPaused();
        taskIndex = ++latestTaskNum;
        
        bytes32 taskHash = keccak256(abi.encode(chainId, poolId, poolState, block.timestamp));
        
        taskMetadata[taskIndex] = TaskMetadata({
            taskIndex: taskIndex,
            taskCreatedBlock: block.number,
            taskHash: taskHash,
            taskDeadline: block.timestamp + taskResponseWindow,
            taskCreator: msg.sender
        });
        
        stateUpdateTasks[taskIndex] = StateUpdateTask({
            chainId: chainId,
            poolId: poolId,
            poolState: poolState,
            timestamp: block.timestamp,
            operatorSignature: ""
        });
        
        emit Events.TaskCreated(taskIndex, taskHash, msg.sender, block.number);
        
        return taskIndex;
    }
    
    function respondToStateUpdateTask(
        uint32 taskIndex,
        StateUpdateTask calldata taskResponse,
        bytes calldata signature
    ) external override onlyRegisteredOperator {
        checkNotPaused();
        TaskMetadata memory task = taskMetadata[taskIndex];
        
        if (task.taskIndex == 0) revert Errors.TaskNotFound(taskIndex);
        if (block.timestamp > task.taskDeadline) revert Errors.TaskExpired(task.taskDeadline, block.timestamp);
        if (taskResponses[taskIndex][msg.sender]) revert Errors.TaskAlreadyResponded(taskIndex);
        
        IStateValidation.ValidationResult memory validation = stateValidation.validateTaskResponse(
            taskIndex,
            abi.encode(taskResponse),
            signature
        );
        
        if (!validation.isValid) {
            _handleInvalidTaskResponse(msg.sender, taskIndex, validation.reason);
            return;
        }
        
        taskResponses[taskIndex][msg.sender] = true;
        operatorInfo[msg.sender].taskResponseCount++;
        
        _updateGlobalPoolState(taskResponse.poolId, taskResponse.chainId, taskResponse.poolState);
        
        bytes32 taskResponseHash = keccak256(abi.encode(taskResponse));
        
        emit Events.TaskResponded(taskIndex, msg.sender, taskResponseHash, block.timestamp);
    }
    
    function createRebalancingTask(
        uint256 sourceChain,
        uint256 targetChain,
        address token,
        uint256 amount
    ) external override returns (bytes32 requestId) {
        checkNotPaused();
        requestId = keccak256(abi.encode(sourceChain, targetChain, token, amount, block.timestamp));
        
        rebalancingTasks[requestId] = RebalancingTask({
            requestId: requestId,
            sourceChain: sourceChain,
            targetChain: targetChain,
            token: token,
            amount: amount,
            deadline: block.timestamp + taskResponseWindow,
            status: TaskStatus.PENDING
        });
        
        emit Events.RebalancingTaskCreated(requestId, sourceChain, targetChain, amount);
        
        return requestId;
    }
    
    function executeRebalancingTask(bytes32 requestId) external override onlyRegisteredOperator {
        checkNotPaused();
        RebalancingTask storage task = rebalancingTasks[requestId];
        
        if (task.status != TaskStatus.PENDING) revert Errors.RebalancingInProgress();
        if (block.timestamp > task.deadline) {
            task.status = TaskStatus.EXPIRED;
            return;
        }
        
        task.status = TaskStatus.COMPLETED;
        emit Events.RebalancingExecuted(requestId, 0, task.amount, 0, block.timestamp);
    }
    
    function getGlobalPoolState(bytes32 poolId)
        external
        view
        override
        returns (
            uint256 totalLiquidity,
            uint256 averagePrice,
            uint256 imbalanceScore,
            uint256 supportedChainsCount,
            uint256 lastUpdateBlock
        )
    {
        AggregatedMetrics memory metrics = aggregatedMetrics[poolId];
        return (
            metrics.totalLiquidity,
            metrics.weightedAveragePrice,
            metrics.maxImbalance,
            0, // supportedChainsCount - simplified
            metrics.lastCalculationBlock
        );
    }
    
    function getAggregatedMetrics(bytes32 poolId)
        external
        view
        override
        returns (AggregatedMetrics memory)
    {
        return aggregatedMetrics[poolId];
    }
    
    function registerOperator(
        address operator,
        string calldata metadataURI
    ) external override {
        uint256 stakeAmount = minimumStakeRequired;
        
        operatorInfo[operator] = OperatorInfo({
            operatorAddress: operator,
            metadataURI: metadataURI,
            stakeAmount: stakeAmount,
            lastActiveBlock: block.number,
            isRegistered: true,
            taskResponseCount: 0,
            slashingCount: 0
        });
        
        emit Events.OperatorRegistered(operator, metadataURI, stakeAmount);
    }
    
    function deregisterOperator(address operator) external override {
        require(msg.sender == operator || msg.sender == owner(), "Not authorized");
        
        operatorInfo[operator].isRegistered = false;
        
        emit Events.OperatorDeregistered(operator, "Voluntary deregistration");
    }
    
    function slashOperator(
        address operator,
        uint256 slashAmount,
        string calldata reason
    ) external override onlyOwner {
        OperatorInfo storage info = operatorInfo[operator];
        
        if (!info.isRegistered) revert Errors.InvalidOperator(operator);
        if (slashAmount > info.stakeAmount) revert Errors.InvalidSlashingAmount(slashAmount, info.stakeAmount);
        
        info.stakeAmount -= slashAmount;
        info.slashingCount++;
        
        emit Events.OperatorSlashed(operator, slashAmount, reason, block.timestamp);
    }
    
    function _updateGlobalPoolState(
        bytes32 poolId,
        uint256 chainId,
        PoolState memory poolState
    ) internal {
        chainStates[poolId][chainId] = poolState;
        
        _recalculateAggregatedMetrics(poolId);
        
        emit Events.GlobalStateUpdated(chainId, poolId, poolState.totalLiquidity, poolState.price, 0, block.timestamp);
    }
    
    function _recalculateAggregatedMetrics(bytes32 poolId) internal {
        uint256 totalLiquidity = 0;
        uint256 weightedPrice = 0;
        uint256 maxImbalance = 0;
        uint256 chainCount = 0;
        
        // Simplified calculation for supported chains (1-5)
        for (uint256 i = 1; i <= 5; i++) {
            PoolState memory state = chainStates[poolId][i];
            if (state.timestamp > 0) {
                totalLiquidity += state.totalLiquidity;
                weightedPrice += state.price * state.totalLiquidity;
                chainCount++;
            }
        }
        
        if (totalLiquidity > 0) {
            weightedPrice = weightedPrice / totalLiquidity;
            uint256 expectedLiquidity = totalLiquidity / chainCount;
            
            for (uint256 i = 1; i <= 5; i++) {
                PoolState memory state = chainStates[poolId][i];
                if (state.timestamp > 0) {
                    uint256 imbalance = _calculateImbalance(state.totalLiquidity, expectedLiquidity);
                    if (imbalance > maxImbalance) {
                        maxImbalance = imbalance;
                    }
                }
            }
        }
        
        aggregatedMetrics[poolId] = AggregatedMetrics({
            totalLiquidity: totalLiquidity,
            weightedAveragePrice: weightedPrice,
            maxImbalance: maxImbalance,
            priceVariance: 0,
            liquidityDistribution: 0,
            lastCalculationBlock: block.number
        });
    }
    
    function _calculateImbalance(uint256 actual, uint256 expected) internal pure returns (uint256) {
        if (expected == 0) return 0;
        uint256 diff = actual > expected ? actual - expected : expected - actual;
        return (diff * Constants.PERCENTAGE_PRECISION) / expected;
    }
    
    function _handleInvalidTaskResponse(
        address operator,
        uint32 taskIndex,
        string memory reason
    ) internal {
        operatorInfo[operator].slashingCount++;
        
        uint256 slashAmount = (operatorInfo[operator].stakeAmount * slashingPenaltyRate) / Constants.PERCENTAGE_PRECISION;
        if (slashAmount > maxSlashingPenalty) {
            slashAmount = maxSlashingPenalty;
        }
        
        if (slashAmount > 0) {
            try this.slashOperator(operator, slashAmount, reason) {} catch {}
        }
        
        emit Events.StateValidationFailed(operator, taskIndex, reason, block.timestamp);
    }
    
    function getOperatorInfo(address operator)
        external
        view
        override
        returns (OperatorInfo memory)
    {
        return operatorInfo[operator];
    }
    
    function isValidOperator(address operator) external view override returns (bool) {
        return operatorInfo[operator].isRegistered;
    }
    
    function getTaskMetadata(uint32 taskIndex)
        external
        view
        override
        returns (TaskMetadata memory)
    {
        return taskMetadata[taskIndex];
    }
    
    function getRebalancingTask(bytes32 requestId)
        external
        view
        override
        returns (RebalancingTask memory)
    {
        return rebalancingTasks[requestId];
    }
    
    function updateSlashingParameters(
        uint256 penaltyRate,
        uint256 maxPenalty
    ) external override onlyOwner {
        if (penaltyRate > Constants.MAX_SLASHING_PENALTY) revert Errors.InvalidThreshold();
        
        slashingPenaltyRate = penaltyRate;
        maxSlashingPenalty = maxPenalty;
    }
    
    function pauseAVS() external override onlyOwner {
        _pause();
        emit Events.EmergencyPaused(msg.sender, "AVS paused", block.timestamp);
    }
    
    function unpauseAVS() external override onlyOwner {
        _unpause();
        emit Events.EmergencyUnpaused(msg.sender, block.timestamp);
    }
}
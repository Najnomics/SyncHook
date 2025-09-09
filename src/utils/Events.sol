// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title Events
 * @author SyncHook Team
 * @notice Centralized event definitions for the SyncHook system
 * @dev Events organized by functionality for comprehensive system monitoring
 */
library Events {
    // ============================================================================
    // OPERATOR MANAGEMENT EVENTS
    // ============================================================================
    
    event OperatorRegistered(
        address indexed operator,
        string metadataURI,
        uint256 stakeAmount
    );
    
    event OperatorDeregistered(
        address indexed operator,
        string reason
    );
    
    event OperatorSlashed(
        address indexed operator,
        uint256 slashAmount,
        string reason,
        uint256 timestamp
    );
    
    event StakeUpdated(
        address indexed operator,
        uint256 oldAmount,
        uint256 newAmount
    );
    
    // ============================================================================
    // TASK MANAGEMENT EVENTS
    // ============================================================================
    
    event TaskCreated(
        uint32 indexed taskIndex,
        bytes32 indexed taskHash,
        address indexed creator,
        uint256 blockNumber
    );
    
    event TaskResponded(
        uint32 indexed taskIndex,
        address indexed operator,
        bytes32 responseHash,
        uint256 timestamp
    );
    
    event StateValidationFailed(
        address indexed validator,
        uint32 indexed taskIndex,
        string reason,
        uint256 timestamp
    );
    
    event TaskCompleted(
        uint32 indexed taskIndex,
        bytes32 indexed taskHash,
        uint256 timestamp
    );
    
    // ============================================================================
    // REBALANCING EVENTS
    // ============================================================================
    
    event RebalancingTaskCreated(
        bytes32 indexed requestId,
        uint256 indexed sourceChain,
        uint256 indexed targetChain,
        uint256 amount
    );
    
    event RebalancingExecuted(
        bytes32 indexed requestId,
        uint256 indexed sourceChain,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );
    
    event RebalancingFailed(
        bytes32 indexed requestId,
        string reason,
        uint256 timestamp
    );
    
    event OptimalRebalancingTargetFound(
        uint256 indexed sourceChain,
        uint256 indexed targetChain,
        uint256 amount,
        uint256 expectedImprovement
    );
    
    // ============================================================================
    // STATE AGGREGATION EVENTS
    // ============================================================================
    
    event GlobalStateUpdated(
        uint256 indexed chainId,
        bytes32 indexed poolId,
        uint256 totalLiquidity,
        uint256 price,
        uint256 imbalanceScore,
        uint256 timestamp
    );
    
    event StateAggregationCompleted(
        bytes32 indexed poolId,
        uint256 totalLiquidity,
        uint256 weightedAveragePrice,
        uint256 maxImbalance,
        uint256 timestamp
    );
    
    event StateValidated(
        uint256 indexed chainId,
        bytes32 indexed poolId,
        address indexed validator,
        IStateValidation.ValidationResult result
    );
    
    event ConsensusReached(
        bytes32 indexed poolId,
        uint256 validatorCount,
        uint256 confidenceScore
    );
    
    // ============================================================================
    // HOOK EVENTS
    // ============================================================================
    
    event SwapOptimized(
        bytes32 indexed poolId,
        address indexed user,
        uint256 optimizedAmount,
        uint256 expectedImprovement,
        uint256 timestamp
    );
    
    event LiquidityRebalanceTriggered(
        bytes32 indexed poolId,
        uint256 indexed sourceChain,
        uint256 imbalanceScore,
        uint256 timestamp
    );
    
    event PoolStateUpdated(
        bytes32 indexed poolId,
        uint256 indexed chainId,
        uint256 newLiquidity,
        uint256 newPrice,
        uint256 timestamp
    );
    
    // ============================================================================
    // EMERGENCY AND GOVERNANCE EVENTS
    // ============================================================================
    
    event EmergencyPaused(
        address indexed admin,
        string reason,
        uint256 timestamp
    );
    
    event EmergencyUnpaused(
        address indexed admin,
        uint256 timestamp
    );
    
    event GovernanceActionProposed(
        bytes32 indexed actionHash,
        address indexed proposer,
        uint256 executionTime
    );
    
    event GovernanceActionExecuted(
        bytes32 indexed actionHash,
        address indexed executor,
        uint256 timestamp
    );
    
    // ============================================================================
    // CONFIGURATION EVENTS
    // ============================================================================
    
    event ChainAdded(
        uint256 indexed chainId,
        address spokePoolAddress,
        bool isActive
    );
    
    event ChainRemoved(
        uint256 indexed chainId,
        string reason
    );
    
    event ThresholdUpdated(
        string indexed parameterName,
        uint256 oldValue,
        uint256 newValue
    );
    
    event ProtocolConfigurationUpdated(
        string indexed protocol,
        address oldAddress,
        address newAddress
    );
    
    // ============================================================================
    // FINANCIAL EVENTS
    // ============================================================================
    
    event FeesCollected(
        address indexed collector,
        uint256 amount,
        string feeType,
        uint256 timestamp
    );
    
    event RewardsDistributed(
        address indexed operator,
        uint256 amount,
        uint256 period,
        uint256 timestamp
    );
    
    event LiquidityProvided(
        bytes32 indexed poolId,
        uint256 indexed chainId,
        address indexed provider,
        uint256 amount,
        uint256 timestamp
    );
    
    event LiquidityWithdrawn(
        bytes32 indexed poolId,
        uint256 indexed chainId,
        address indexed provider,
        uint256 amount,
        uint256 timestamp
    );
    
    // ============================================================================
    // CROSS-CHAIN EVENTS
    // ============================================================================
    
    event CrossChainMessageSent(
        uint256 indexed sourceChain,
        uint256 indexed targetChain,
        bytes32 indexed messageHash,
        bytes data
    );
    
    event CrossChainMessageReceived(
        uint256 indexed sourceChain,
        uint256 indexed targetChain,
        bytes32 indexed messageHash,
        bool success
    );
    
    event BridgeOperationInitiated(
        bytes32 indexed operationId,
        uint256 indexed sourceChain,
        uint256 indexed targetChain,
        uint256 amount,
        address token
    );
    
    event BridgeOperationCompleted(
        bytes32 indexed operationId,
        bool success,
        uint256 timestamp
    );
    
    // ============================================================================
    // MONITORING AND ANALYTICS EVENTS
    // ============================================================================
    
    event MetricsCalculated(
        bytes32 indexed poolId,
        uint256 totalVolume,
        uint256 averagePrice,
        uint256 liquidityUtilization,
        uint256 timestamp
    );
    
    event AnomalyDetected(
        bytes32 indexed poolId,
        uint256 indexed chainId,
        string anomalyType,
        uint256 severity,
        uint256 timestamp
    );
    
    event PerformanceMetrics(
        string indexed component,
        uint256 gasUsed,
        uint256 executionTime,
        bool success,
        uint256 timestamp
    );
}

// Interface reference for events that use external types
interface IStateValidation {
    struct ValidationResult {
        bool isValid;
        string reason;
        uint256 confidence;
        uint256 timestamp;
        address validator;
    }
}
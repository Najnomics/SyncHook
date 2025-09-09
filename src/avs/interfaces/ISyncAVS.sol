// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title ISyncAVS
 * @author SyncHook Team
 * @notice Interface for the SyncAVS (Actively Validated Service)
 */
interface ISyncAVS {
    // ============================================================================
    // STRUCTS
    // ============================================================================
    
    struct TaskMetadata {
        uint32 taskIndex;
        uint256 taskCreatedBlock;
        bytes32 taskHash;
        uint256 taskDeadline;
        address taskCreator;
    }
    
    struct StateUpdateTask {
        uint256 chainId;
        bytes32 poolId;
        PoolState poolState;
        uint256 timestamp;
        bytes operatorSignature;
    }
    
    struct RebalancingTask {
        bytes32 requestId;
        uint256 sourceChain;
        uint256 targetChain;
        address token;
        uint256 amount;
        uint256 deadline;
        TaskStatus status;
    }
    
    struct OperatorInfo {
        address operatorAddress;
        string metadataURI;
        uint256 stakeAmount;
        uint256 lastActiveBlock;
        bool isRegistered;
        uint256 taskResponseCount;
        uint256 slashingCount;
    }
    
    struct PoolState {
        uint256 totalLiquidity;
        uint256 price;
        uint256 volume24h;
        uint256 fees24h;
        uint256 timestamp;
        uint256 blockNumber;
    }
    
    enum TaskStatus {
        PENDING,
        IN_PROGRESS,
        COMPLETED,
        FAILED,
        EXPIRED
    }
    
    // ============================================================================
    // TASK MANAGEMENT
    // ============================================================================
    
    function createStateUpdateTask(
        uint256 chainId,
        bytes32 poolId,
        PoolState calldata poolState
    ) external returns (uint32 taskIndex);
    
    function respondToStateUpdateTask(
        uint32 taskIndex,
        StateUpdateTask calldata taskResponse,
        bytes calldata signature
    ) external;
    
    function createRebalancingTask(
        uint256 sourceChain,
        uint256 targetChain,
        address token,
        uint256 amount
    ) external returns (bytes32 requestId);
    
    function executeRebalancingTask(bytes32 requestId) external;
    
    // ============================================================================
    // STATE QUERIES
    // ============================================================================
    
    function getGlobalPoolState(bytes32 poolId) external view returns (
        uint256 totalLiquidity,
        uint256 averagePrice,
        uint256 imbalanceScore,
        uint256 supportedChainsCount,
        uint256 lastUpdateBlock
    );
    function getAggregatedMetrics(bytes32 poolId) external view returns (AggregatedMetrics memory);
    function getOperatorInfo(address operator) external view returns (OperatorInfo memory);
    function isValidOperator(address operator) external view returns (bool);
    function getTaskMetadata(uint32 taskIndex) external view returns (TaskMetadata memory);
    function getRebalancingTask(bytes32 requestId) external view returns (RebalancingTask memory);
    
    // ============================================================================
    // OPERATOR MANAGEMENT
    // ============================================================================
    
    function registerOperator(address operator, string calldata metadataURI) external;
    function deregisterOperator(address operator) external;
    function slashOperator(address operator, uint256 slashAmount, string calldata reason) external;
    function updateSlashingParameters(uint256 penaltyRate, uint256 maxPenalty) external;
    
    // ============================================================================
    // EMERGENCY CONTROLS
    // ============================================================================
    
    function pauseAVS() external;
    function unpauseAVS() external;
    
    // ============================================================================
    // SUPPORTING STRUCTS FROM OTHER INTERFACES
    // ============================================================================
    
    struct GlobalPoolState {
        mapping(uint256 => PoolState) chainStates;
        uint256 totalLiquidity;
        uint256 averagePrice;
        uint256 imbalanceScore;
        uint256 supportedChainsCount;
        uint256 lastUpdateBlock;
    }
    
    struct AggregatedMetrics {
        uint256 totalLiquidity;
        uint256 weightedAveragePrice;
        uint256 maxImbalance;
        uint256 priceVariance;
        uint256 liquidityDistribution;
        uint256 lastCalculationBlock;
    }
}
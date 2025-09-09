// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

/**
 * @title ISyncAVS
 * @notice Interface for SyncAVS - EigenLayer AVS Service Manager
 * @dev This interface defines the contract for the EigenLayer AVS that aggregates
 *      pool states from multiple chains and coordinates cross-chain rebalancing
 */
interface ISyncAVS {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Global pool state aggregated across all chains
     * @param chainStates Mapping of chainId => pool state
     * @param totalLiquidity Sum of liquidity across all chains
     * @param averagePrice Liquidity-weighted average price
     * @param imbalanceScore Maximum imbalance percentage across chains
     * @param lastUpdateBlock Block when metrics were last calculated
     */
    struct GlobalPoolState {
        mapping(uint256 => PoolState) chainStates;
        uint256 totalLiquidity;
        uint256 averagePrice;
        uint256 imbalanceScore;
        uint256 lastUpdateBlock;
    }
    
    /**
     * @notice Pool state for a specific chain
     * @param totalLiquidity Total liquidity in the pool
     * @param price Current price of the pool
     * @param volume24h 24-hour trading volume
     * @param fees24h 24-hour fees collected
     * @param timestamp Last update timestamp
     * @param blockNumber Last update block number
     */
    struct PoolState {
        uint256 totalLiquidity;
        uint256 price;
        uint256 volume24h;
        uint256 fees24h;
        uint256 timestamp;
        uint256 blockNumber;
    }
    
    /**
     * @notice Rebalancing task for cross-chain liquidity movement
     * @param taskId Unique task identifier
     * @param sourceChain Source chain ID
     * @param targetChain Target chain ID
     * @param amount Amount to transfer
     * @param token Token to transfer
     * @param deadline Task deadline
     * @param status Task status
     */
    struct RebalancingTask {
        uint256 taskId;
        uint256 sourceChain;
        uint256 targetChain;
        uint256 amount;
        address token;
        uint256 deadline;
        TaskStatus status;
    }
    
    /**
     * @notice Task status enumeration
     */
    enum TaskStatus {
        Pending,
        InProgress,
        Completed,
        Failed,
        Cancelled
    }
    
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event StateUpdated(uint256 indexed chainId, uint256 liquidity, uint256 price);
    event RebalancingInitiated(uint256 indexed taskId, uint256 sourceChain, uint256 targetChain, uint256 amount);
    event TaskCompleted(uint256 indexed taskId, bool success);
    event OperatorRegistered(address indexed operator, string metadataURI);
    event OperatorDeregistered(address indexed operator);
    
    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Submit state update for a specific chain
     * @param chainId Chain identifier
     * @param poolState Pool state information
     * @param signature Operator signature for validation
     */
    function submitStateUpdate(
        uint256 chainId,
        PoolState calldata poolState,
        bytes calldata signature
    ) external;
    
    /**
     * @notice Get global pool state for a currency pair
     * @param currency0 First currency
     * @param currency1 Second currency
     * @return totalLiquidity Total liquidity across all chains
     * @return averagePrice Average price across all chains
     * @return imbalanceScore Current imbalance score
     * @return lastUpdateBlock Block number of last update
     */
    function getGlobalState(
        Currency currency0,
        Currency currency1
    ) external view returns (
        uint256 totalLiquidity,
        uint256 averagePrice,
        uint256 imbalanceScore,
        uint256 lastUpdateBlock
    );
    
    /**
     * @notice Check if rebalancing should be triggered
     * @param currency0 First currency
     * @param currency1 Second currency
     * @return shouldTrigger Whether rebalancing should be triggered
     * @return sourceChain Source chain for rebalancing
     * @return targetChain Target chain for rebalancing
     * @return amount Amount to rebalance
     */
    function shouldTriggerRebalancing(
        Currency currency0,
        Currency currency1
    ) external view returns (
        bool shouldTrigger,
        uint256 sourceChain,
        uint256 targetChain,
        uint256 amount
    );
    
    /**
     * @notice Initiate rebalancing task
     * @param sourceChain Source chain ID
     * @param targetChain Target chain ID
     * @param amount Amount to transfer
     * @param token Token to transfer
     * @return taskId Created task ID
     */
    function initiateRebalancing(
        uint256 sourceChain,
        uint256 targetChain,
        uint256 amount,
        address token
    ) external returns (uint256 taskId);
    
    /**
     * @notice Get rebalancing task by ID
     * @param taskId Task identifier
     * @return RebalancingTask Task information
     */
    function getRebalancingTask(uint256 taskId) external view returns (RebalancingTask memory);
    
    /**
     * @notice Update task status
     * @param taskId Task identifier
     * @param status New status
     */
    function updateTaskStatus(uint256 taskId, TaskStatus status) external;
    
    /*//////////////////////////////////////////////////////////////
                            OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Register as an AVS operator
     * @param operator Operator address
     * @param metadataURI Operator metadata URI
     */
    function registerOperator(address operator, string calldata metadataURI) external;
    
    /**
     * @notice Deregister operator
     * @param operator Operator address
     */
    function deregisterOperator(address operator) external;
    
    /**
     * @notice Check if address is registered operator
     * @param operator Operator address
     * @return bool Whether operator is registered
     */
    function isRegisteredOperator(address operator) external view returns (bool);
    
    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Pause the AVS
     */
    function pauseAVS() external;
    
    /**
     * @notice Unpause the AVS
     */
    function unpauseAVS() external;
    
    /**
     * @notice Update slashing parameters
     * @param newSlashingPercentage New slashing percentage
     * @param newMinStake New minimum stake requirement
     */
    function updateSlashingParameters(uint256 newSlashingPercentage, uint256 newMinStake) external;
    
    /**
     * @notice Slash operator for misbehavior
     * @param operator Operator address
     * @param amount Amount to slash
     */
    function slashOperator(address operator, uint256 amount) external;
}

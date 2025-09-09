// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IStateAggregator
 * @author SyncHook Team
 * @notice Interface for cross-chain state aggregation functionality
 * @dev Handles aggregation of pool states across multiple blockchains
 */

interface IStateAggregator {
    // ============================================================================
    // STRUCTS
    // ============================================================================
    
    /**
     * @notice Chain-specific pool state information
     * @param liquidity Total liquidity in the pool on this chain
     * @param price Current price of the pool
     * @param volume24h 24-hour trading volume
     * @param lastUpdate Last update timestamp
     * @param isActive Whether the chain state is active
     */
    struct ChainPoolState {
        uint256 liquidity;
        uint256 price;
        uint256 volume24h;
        uint256 lastUpdate;
        bool isActive;
    }
    
    /**
     * @notice Aggregated metrics across all chains for a pool
     * @param totalLiquidity Sum of liquidity across all chains
     * @param averagePrice Liquidity-weighted average price
     * @param maxImbalance Maximum imbalance percentage across chains
     * @param supportedChains Number of active supported chains
     * @param lastUpdate Timestamp of last update
     */
    struct AggregatedMetrics {
        uint256 totalLiquidity;
        uint256 averagePrice;
        uint256 maxImbalance;
        uint256 supportedChains;
        uint256 lastUpdate;
    }
    
    /**
     * @notice Rebalancing recommendation for optimal liquidity distribution
     * @param sourceChain Chain to move liquidity from
     * @param targetChain Chain to move liquidity to
     * @param optimalAmount Recommended amount to move
     * @param expectedImprovement Expected improvement in imbalance score
     * @param estimatedCost Estimated cost of rebalancing
     * @param urgencyLevel Urgency level (0-100)
     */
    struct RebalancingRecommendation {
        uint256 sourceChain;
        uint256 targetChain;
        uint256 optimalAmount;
        uint256 expectedImprovement;
        uint256 estimatedCost;
        uint256 urgencyLevel;
    }
    
    /**
     * @notice Validation result for cross-chain state consistency
     * @param isValid Whether the state is valid
     * @param confidence Confidence score (0-10000)
     * @param inconsistencies Array of detected inconsistencies
     * @param recommendedActions Recommended actions to resolve issues
     */
    struct ValidationResult {
        bool isValid;
        uint256 confidence;
        string[] inconsistencies;
        string[] recommendedActions;
    }
    
    /**
     * @notice Chain-specific information for aggregation
     * @param chainId Blockchain identifier
     * @param isActive Whether the chain is active
     * @param weight Weight for aggregation calculations
     * @param lastUpdate Timestamp of last update
     * @param reliability Reliability score (0-10000)
     */
    struct ChainInfo {
        uint256 chainId;
        bool isActive;
        uint256 weight;
        uint256 lastUpdate;
        uint256 reliability;
    }
    
    // ============================================================================
    // AGGREGATION FUNCTIONS
    // ============================================================================
    
    /**
     * @notice Aggregates pool states from all supported chains
     * @param poolKey The pool identifier
     * @return AggregatedMetrics Combined metrics across all chains
     */
    function aggregatePoolStates(bytes32 poolKey) external view returns (AggregatedMetrics memory);
    
    /**
     * @notice Updates pool state for a specific chain
     * @param poolKey The pool identifier
     * @param chainId Chain identifier
     * @param state New state information
     */
    function updateChainState(
        bytes32 poolKey,
        uint256 chainId,
        ChainPoolState memory state
    ) external;
    
    /**
     * @notice Gets pool state for a specific chain
     * @param poolKey The pool identifier
     * @param chainId Chain identifier
     * @return ChainPoolState State information
     */
    function getChainState(bytes32 poolKey, uint256 chainId) external view returns (ChainPoolState memory);
    
    /**
     * @notice Gets pool state for a specific chain
     * @param poolKey The pool identifier
     * @param chainId Chain identifier
     * @return liquidity Total liquidity
     * @return price Current price
     * @return volume24h 24-hour volume
     * @return fees24h 24-hour fees
     * @return timestamp Last update timestamp
     * @return blockNumber Last update block number
     */
    function getPoolState(bytes32 poolKey, uint256 chainId) external view returns (
        uint256 liquidity,
        uint256 price,
        uint256 volume24h,
        uint256 fees24h,
        uint256 timestamp,
        uint256 blockNumber
    );
    
    // ============================================================================
    // REBALANCING FUNCTIONS
    // ============================================================================
    
    /**
     * @notice Gets rebalancing recommendation for a pool
     * @param poolKey The pool identifier
     * @return RebalancingRecommendation Optimal rebalancing strategy
     */
    function getRebalancingRecommendation(bytes32 poolKey) external view returns (RebalancingRecommendation memory);
    
    /**
     * @notice Calculates optimal rebalancing between two specific chains
     * @param poolKey The pool identifier
     * @param sourceChain Source chain ID
     * @param targetChain Target chain ID
     * @param maxAmount Maximum amount to rebalance
     * @return optimalAmount Recommended amount
     * @return expectedImprovement Expected improvement score
     */
    function calculateOptimalRebalancing(
        bytes32 poolKey,
        uint256 sourceChain,
        uint256 targetChain,
        uint256 maxAmount
    ) external view returns (uint256 optimalAmount, uint256 expectedImprovement);
    
    /**
     * @notice Checks if immediate rebalancing is recommended
     * @param poolKey The pool identifier
     * @param imbalanceThreshold Threshold for triggering rebalancing
     * @return shouldRebalance Whether rebalancing is recommended
     * @return urgencyLevel Urgency level (0-100)
     */
    function shouldTriggerRebalancing(bytes32 poolKey, uint256 imbalanceThreshold) external view returns (
        bool shouldRebalance,
        uint256 urgencyLevel
    );
    
    // ============================================================================
    // VALIDATION FUNCTIONS
    // ============================================================================
    
    /**
     * @notice Validates cross-chain state consistency
     * @param poolKey The pool identifier
     * @param maxPriceDeviation Maximum allowed price deviation
     * @param maxTimeDrift Maximum allowed time drift between chains
     * @return ValidationResult Validation results and recommendations
     */
    function validateStateConsistency(
        bytes32 poolKey,
        uint256 maxPriceDeviation,
        uint256 maxTimeDrift
    ) external view returns (ValidationResult memory);
    
    /**
     * @notice Detects anomalies in cross-chain data
     * @param poolKey The pool identifier
     * @param chainId Specific chain to check (0 for all chains)
     * @return hasAnomalies Whether anomalies were detected
     * @return anomalyTypes Array of detected anomaly types
     * @return severity Severity score (0-100)
     */
    function detectAnomalies(bytes32 poolKey, uint256 chainId) external view returns (
        bool hasAnomalies,
        string[] memory anomalyTypes,
        uint256 severity
    );
    
    // ============================================================================
    // CONFIGURATION FUNCTIONS
    // ============================================================================
    
    /**
     * @notice Adds or updates a supported chain
     * @param chainId Chain identifier
     * @param weight Aggregation weight
     * @param isActive Whether the chain is active
     */
    function configureChain(uint256 chainId, uint256 weight, bool isActive) external;
    
    /**
     * @notice Removes a supported chain
     * @param chainId Chain identifier
     */
    function removeChain(uint256 chainId) external;
    
    /**
     * @notice Gets information about a supported chain
     * @param chainId Chain identifier
     * @return ChainInfo Chain configuration
     */
    function getChainInfo(uint256 chainId) external view returns (ChainInfo memory);
    
    /**
     * @notice Gets all supported chain IDs
     * @return Array of supported chain IDs
     */
    function getSupportedChains() external view returns (uint256[] memory);
    
    /**
     * @notice Adds a supported chain
     * @param chainId Chain identifier
     */
    function addSupportedChain(uint256 chainId) external;
    
    /**
     * @notice Removes a supported chain
     * @param chainId Chain identifier
     */
    function removeSupportedChain(uint256 chainId) external;
    
    /**
     * @notice Checks if a chain is supported
     * @param chainId Chain identifier
     * @return bool Whether the chain is supported
     */
    function isSupportedChain(uint256 chainId) external view returns (bool);
    
    /**
     * @notice Adds an authorized caller
     * @param caller Address to authorize
     */
    function addAuthorizedCaller(address caller) external;
    
    /**
     * @notice Removes an authorized caller
     * @param caller Address to remove
     */
    function removeAuthorizedCaller(address caller) external;
    
    /**
     * @notice Checks if an address is authorized
     * @param caller Address to check
     * @return bool Whether the address is authorized
     */
    function isAuthorizedCaller(address caller) external view returns (bool);
    
    /**
     * @notice Updates aggregation parameters
     * @param maxStaleTime Maximum age for data to be considered fresh
     * @param minConfidence Minimum confidence threshold
     * @param rebalanceThreshold Default rebalancing threshold
     */
    function updateAggregationParams(
        uint256 maxStaleTime,
        uint256 minConfidence,
        uint256 rebalanceThreshold
    ) external;
    
    // ============================================================================
    // ANALYTICS FUNCTIONS
    // ============================================================================
    
    /**
     * @notice Gets historical metrics for a pool
     * @param poolKey The pool identifier
     * @param fromTimestamp Start timestamp
     * @param toTimestamp End timestamp
     * @return timestamps Array of timestamps
     * @return totalLiquidity Array of total liquidity values
     * @return averagePrices Array of average prices
     * @return imbalanceScores Array of imbalance scores
     */
    function getHistoricalMetrics(
        bytes32 poolKey,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external view returns (
        uint256[] memory timestamps,
        uint256[] memory totalLiquidity,
        uint256[] memory averagePrices,
        uint256[] memory imbalanceScores
    );
    
    /**
     * @notice Gets performance statistics for the aggregator
     * @return totalPools Number of pools being tracked
     * @return totalChains Number of active chains
     * @return lastUpdateTime Timestamp of last successful update
     * @return averageConfidence Average confidence score
     * @return totalRebalancingEvents Number of rebalancing events
     */
    function getPerformanceStats() external view returns (
        uint256 totalPools,
        uint256 totalChains,
        uint256 lastUpdateTime,
        uint256 averageConfidence,
        uint256 totalRebalancingEvents
    );
    
    // ============================================================================
    // EVENTS
    // ============================================================================
    
    event PoolStateUpdated(
        bytes32 indexed poolKey,
        uint256 indexed chainId,
        uint256 liquidity,
        uint256 price,
        uint256 timestamp
    );
    
    event AggregationCompleted(
        bytes32 indexed poolKey,
        uint256 totalLiquidity,
        uint256 averagePrice,
        uint256 maxImbalance,
        uint256 timestamp
    );
    
    event RebalancingRecommended(
        bytes32 indexed poolKey,
        uint256 indexed sourceChain,
        uint256 indexed targetChain,
        uint256 amount,
        uint256 urgencyLevel
    );
    
    event AnomalyDetected(
        bytes32 indexed poolKey,
        uint256 indexed chainId,
        string anomalyType,
        uint256 severity,
        uint256 timestamp
    );
    
    event ChainConfigured(
        uint256 indexed chainId,
        uint256 weight,
        bool isActive
    );
    
    event ValidationCompleted(
        bytes32 indexed poolKey,
        bool isValid,
        uint256 confidence,
        uint256 timestamp
    );
}
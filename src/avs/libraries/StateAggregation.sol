// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title StateAggregation
 * @notice Library for aggregating and processing multi-chain state data
 * @dev Provides utilities for calculating global metrics from chain states
 */
library StateAggregation {
    /// @notice Precision for calculations (18 decimals)
    uint256 public constant PRECISION = 1e18;
    
    /// @notice Maximum number of supported chains
    uint256 public constant MAX_CHAINS = 20;
    
    /// @notice Minimum confidence threshold for aggregated data (80%)
    uint256 public constant MIN_CONFIDENCE_THRESHOLD = 80e16; // 80%
    
    /// @notice Maximum age for state data (1 hour in blocks, assuming 12s block time)
    uint256 public constant MAX_STATE_AGE = 300; // 300 blocks

    /**
     * @notice Chain state data structure
     * @param chainId Chain identifier
     * @param liquidity Total liquidity in USD
     * @param price Current price (token1/token0)
     * @param volume24h 24-hour trading volume
     * @param lastUpdateBlock Block number of last update
     * @param confidence Confidence score (0-100%)
     * @param isValid Whether the state is valid
     */
    struct ChainState {
        uint256 chainId;
        uint256 liquidity;
        uint256 price;
        uint256 volume24h;
        uint256 lastUpdateBlock;
        uint256 confidence;
        bool isValid;
    }

    /**
     * @notice Aggregated global state
     * @param totalLiquidity Sum of all chain liquidity
     * @param averagePrice Weighted average price
     * @param priceVariance Price variance across chains
     * @param imbalanceScore Maximum imbalance between chains
     * @param totalVolume24h Sum of 24h volume across chains
     * @param confidenceScore Overall confidence in aggregated data
     * @param lastUpdateBlock Block number of last aggregation
     * @param activeChains Number of chains with valid data
     */
    struct AggregatedState {
        uint256 totalLiquidity;
        uint256 averagePrice;
        uint256 priceVariance;
        uint256 imbalanceScore;
        uint256 totalVolume24h;
        uint256 confidenceScore;
        uint256 lastUpdateBlock;
        uint256 activeChains;
    }

    /**
     * @notice Aggregate states from multiple chains
     * @param chainStates Array of chain states
     * @param currentBlock Current block number
     * @return aggregatedState Aggregated global state
     */
    function aggregateStates(
        ChainState[] memory chainStates,
        uint256 currentBlock
    ) internal pure returns (AggregatedState memory aggregatedState) {
        require(chainStates.length > 0, "No chain states provided");
        require(chainStates.length <= MAX_CHAINS, "Too many chains");
        
        uint256 totalLiquidity = 0;
        uint256 weightedPriceSum = 0;
        uint256 totalWeight = 0;
        uint256 totalVolume24h = 0;
        uint256 validChains = 0;
        uint256 confidenceSum = 0;
        
        // First pass: calculate basic metrics
        for (uint256 i = 0; i < chainStates.length; i++) {
            ChainState memory state = chainStates[i];
            
            // Check if state is valid and not too old
            if (state.isValid && 
                currentBlock - state.lastUpdateBlock <= MAX_STATE_AGE &&
                state.confidence >= MIN_CONFIDENCE_THRESHOLD) {
                
                totalLiquidity += state.liquidity;
                weightedPriceSum += state.price * state.liquidity;
                totalWeight += state.liquidity;
                totalVolume24h += state.volume24h;
                confidenceSum += state.confidence;
                validChains++;
            }
        }
        
        require(validChains > 0, "No valid chain states");
        
        // Calculate weighted average price
        uint256 averagePrice = totalWeight > 0 ? weightedPriceSum / totalWeight : 0;
        
        // Second pass: calculate variance and imbalance
        uint256 priceVariance = 0;
        uint256 maxImbalance = 0;
        uint256 expectedLiquidityPerChain = totalLiquidity / validChains;
        
        for (uint256 i = 0; i < chainStates.length; i++) {
            ChainState memory state = chainStates[i];
            
            if (state.isValid && 
                currentBlock - state.lastUpdateBlock <= MAX_STATE_AGE &&
                state.confidence >= MIN_CONFIDENCE_THRESHOLD) {
                
                // Calculate price variance
                if (averagePrice > 0) {
                    uint256 priceDiff = _abs(state.price, averagePrice);
                    priceVariance += (priceDiff * priceDiff) / PRECISION;
                }
                
                // Calculate imbalance
                uint256 liquidityDeviation = _abs(state.liquidity, expectedLiquidityPerChain);
                uint256 imbalancePercent = (liquidityDeviation * PRECISION) / expectedLiquidityPerChain;
                
                if (imbalancePercent > maxImbalance) {
                    maxImbalance = imbalancePercent;
                }
            }
        }
        
        // Calculate final metrics
        priceVariance = validChains > 1 ? priceVariance / (validChains - 1) : 0;
        uint256 confidenceScore = validChains > 0 ? confidenceSum / validChains : 0;
        
        return AggregatedState({
            totalLiquidity: totalLiquidity,
            averagePrice: averagePrice,
            priceVariance: priceVariance,
            imbalanceScore: maxImbalance,
            totalVolume24h: totalVolume24h,
            confidenceScore: confidenceScore,
            lastUpdateBlock: currentBlock,
            activeChains: validChains
        });
    }

    /**
     * @notice Calculate rebalancing recommendations
     * @param chainStates Array of chain states
     * @param aggregatedState Current aggregated state
     * @return rebalancingChains Array of chains that need rebalancing
     * @return rebalancingAmounts Array of amounts to rebalance
     */
    function calculateRebalancingRecommendations(
        ChainState[] memory chainStates,
        AggregatedState memory aggregatedState
    ) internal pure returns (
        uint256[] memory rebalancingChains,
        int256[] memory rebalancingAmounts
    ) {
        require(chainStates.length > 0, "No chain states provided");
        
        // Count valid chains
        uint256 validChainCount = 0;
        for (uint256 i = 0; i < chainStates.length; i++) {
            if (chainStates[i].isValid) {
                validChainCount++;
            }
        }
        
        require(validChainCount > 1, "Need at least 2 valid chains for rebalancing");
        
        uint256 expectedLiquidityPerChain = aggregatedState.totalLiquidity / validChainCount;
        uint256 threshold = expectedLiquidityPerChain * 20 / 100; // 20% threshold
        
        // Temporary arrays to store results
        uint256[] memory tempChains = new uint256[](validChainCount);
        int256[] memory tempAmounts = new int256[](validChainCount);
        uint256 resultCount = 0;
        
        for (uint256 i = 0; i < chainStates.length; i++) {
            ChainState memory state = chainStates[i];
            
            if (state.isValid) {
                int256 deviation = int256(state.liquidity) - int256(expectedLiquidityPerChain);
                
                // Only rebalance if deviation exceeds threshold
                if (_abs(deviation, 0) > threshold) {
                    tempChains[resultCount] = state.chainId;
                    tempAmounts[resultCount] = deviation / 2; // Move half of deviation
                    resultCount++;
                }
            }
        }
        
        // Create final arrays with correct size
        rebalancingChains = new uint256[](resultCount);
        rebalancingAmounts = new int256[](resultCount);
        
        for (uint256 i = 0; i < resultCount; i++) {
            rebalancingChains[i] = tempChains[i];
            rebalancingAmounts[i] = tempAmounts[i];
        }
    }

    /**
     * @notice Calculate confidence score for a chain state
     * @param state Chain state to evaluate
     * @param currentBlock Current block number
     * @param historicalStates Array of recent historical states
     * @return confidence Confidence score (0-100%)
     */
    function calculateConfidenceScore(
        ChainState memory state,
        uint256 currentBlock,
        ChainState[] memory historicalStates
    ) internal pure returns (uint256 confidence) {
        confidence = 100e16; // Start with 100%
        
        // Reduce confidence based on age
        uint256 ageInBlocks = currentBlock - state.lastUpdateBlock;
        if (ageInBlocks > MAX_STATE_AGE) {
            confidence = 0;
            return confidence;
        }
        
        uint256 agePenalty = (ageInBlocks * 1e16) / MAX_STATE_AGE; // Linear penalty
        confidence = confidence > agePenalty ? confidence - agePenalty : 0;
        
        // Reduce confidence based on price volatility
        if (historicalStates.length > 1) {
            uint256 priceVolatility = _calculatePriceVolatility(state, historicalStates);
            uint256 volatilityPenalty = (priceVolatility * 2e16) / 1e18; // 2x penalty
            confidence = confidence > volatilityPenalty ? confidence - volatilityPenalty : 0;
        }
        
        // Reduce confidence based on liquidity changes
        if (historicalStates.length > 0) {
            uint256 liquidityVolatility = _calculateLiquidityVolatility(state, historicalStates);
            uint256 liquidityPenalty = (liquidityVolatility * 1e16) / 1e18; // 1x penalty
            confidence = confidence > liquidityPenalty ? confidence - liquidityPenalty : 0;
        }
        
        // Ensure minimum confidence
        confidence = confidence < 10e16 ? 10e16 : confidence; // Minimum 10%
    }

    /**
     * @notice Detect anomalies in chain states
     * @param chainStates Array of chain states
     * @param aggregatedState Current aggregated state
     * @return anomalyChains Array of chains with anomalies
     * @return anomalyTypes Array of anomaly types
     */
    function detectAnomalies(
        ChainState[] memory chainStates,
        AggregatedState memory aggregatedState
    ) internal pure returns (
        uint256[] memory anomalyChains,
        uint256[] memory anomalyTypes
    ) {
        require(chainStates.length > 0, "No chain states provided");
        
        // Temporary arrays
        uint256[] memory tempChains = new uint256[](chainStates.length);
        uint256[] memory tempTypes = new uint256[](chainStates.length);
        uint256 anomalyCount = 0;
        
        for (uint256 i = 0; i < chainStates.length; i++) {
            ChainState memory state = chainStates[i];
            uint256 anomalyType = 0;
            
            if (state.isValid) {
                // Check for price anomaly (deviation > 3 standard deviations)
                if (aggregatedState.averagePrice > 0) {
                    uint256 priceDeviation = _abs(state.price, aggregatedState.averagePrice);
                    uint256 priceThreshold = (aggregatedState.averagePrice * 15) / 100; // 15%
                    
                    if (priceDeviation > priceThreshold) {
                        anomalyType |= 1; // Price anomaly
                    }
                }
                
                // Check for liquidity anomaly (deviation > 50% from expected)
                uint256 expectedLiquidity = aggregatedState.totalLiquidity / aggregatedState.activeChains;
                uint256 liquidityDeviation = _abs(state.liquidity, expectedLiquidity);
                uint256 liquidityThreshold = expectedLiquidity / 2; // 50%
                
                if (liquidityDeviation > liquidityThreshold) {
                    anomalyType |= 2; // Liquidity anomaly
                }
                
                // Check for volume anomaly (unusually high volume)
                uint256 expectedVolume = aggregatedState.totalVolume24h / aggregatedState.activeChains;
                if (state.volume24h > expectedVolume * 5) { // 5x expected volume
                    anomalyType |= 4; // Volume anomaly
                }
                
                // Check for confidence anomaly (very low confidence)
                if (state.confidence < 30e16) { // Less than 30%
                    anomalyType |= 8; // Confidence anomaly
                }
                
                if (anomalyType > 0) {
                    tempChains[anomalyCount] = state.chainId;
                    tempTypes[anomalyCount] = anomalyType;
                    anomalyCount++;
                }
            }
        }
        
        // Create final arrays
        anomalyChains = new uint256[](anomalyCount);
        anomalyTypes = new uint256[](anomalyCount);
        
        for (uint256 i = 0; i < anomalyCount; i++) {
            anomalyChains[i] = tempChains[i];
            anomalyTypes[i] = tempTypes[i];
        }
    }

    // ============ Internal Helper Functions ============

    function _abs(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function _abs(int256 a, int256 b) internal pure returns (uint256) {
        return a > b ? uint256(a - b) : uint256(b - a);
    }

    function _calculatePriceVolatility(
        ChainState memory currentState,
        ChainState[] memory historicalStates
    ) internal pure returns (uint256 volatility) {
        if (historicalStates.length < 2) return 0;
        
        uint256 sum = 0;
        uint256 count = 0;
        
        for (uint256 i = 0; i < historicalStates.length; i++) {
            if (historicalStates[i].chainId == currentState.chainId && 
                historicalStates[i].isValid) {
                sum += historicalStates[i].price;
                count++;
            }
        }
        
        if (count < 2) return 0;
        
        uint256 mean = sum / count;
        uint256 variance = 0;
        
        for (uint256 i = 0; i < historicalStates.length; i++) {
            if (historicalStates[i].chainId == currentState.chainId && 
                historicalStates[i].isValid) {
                uint256 diff = _abs(historicalStates[i].price, mean);
                variance += (diff * diff) / PRECISION;
            }
        }
        
        volatility = variance / count;
    }

    function _calculateLiquidityVolatility(
        ChainState memory currentState,
        ChainState[] memory historicalStates
    ) internal pure returns (uint256 volatility) {
        if (historicalStates.length < 2) return 0;
        
        uint256 sum = 0;
        uint256 count = 0;
        
        for (uint256 i = 0; i < historicalStates.length; i++) {
            if (historicalStates[i].chainId == currentState.chainId && 
                historicalStates[i].isValid) {
                sum += historicalStates[i].liquidity;
                count++;
            }
        }
        
        if (count < 2) return 0;
        
        uint256 mean = sum / count;
        uint256 variance = 0;
        
        for (uint256 i = 0; i < historicalStates.length; i++) {
            if (historicalStates[i].chainId == currentState.chainId && 
                historicalStates[i].isValid) {
                uint256 diff = _abs(historicalStates[i].liquidity, mean);
                variance += (diff * diff) / PRECISION;
            }
        }
        
        volatility = variance / count;
    }
}

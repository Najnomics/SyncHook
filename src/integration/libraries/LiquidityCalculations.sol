// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title LiquidityCalculations
 * @notice Library for liquidity calculations and rebalancing math
 * @dev Provides utilities for calculating optimal liquidity distribution and rebalancing amounts
 */
library LiquidityCalculations {
    /// @notice Precision for calculations (18 decimals)
    uint256 public constant PRECISION = 1e18;
    
    /// @notice Maximum rebalancing amount (50% of pool liquidity)
    uint256 public constant MAX_REBALANCING_AMOUNT = 50e16; // 50%
    
    /// @notice Minimum rebalancing threshold (5% imbalance)
    uint256 public constant MIN_REBALANCING_THRESHOLD = 5e16; // 5%
    
    /// @notice Maximum slippage tolerance for rebalancing (2%)
    uint256 public constant MAX_REBALANCING_SLIPPAGE = 2e16; // 2%
    
    /// @notice Gas cost per rebalancing operation (in wei)
    uint256 public constant REBALANCING_GAS_COST = 200000; // 200k gas

    /**
     * @notice Pool liquidity state
     * @param totalLiquidity Total liquidity in the pool
     * @param token0Reserves Token0 reserves
     * @param token1Reserves Token1 reserves
     * @param price Current price (token1/token0)
     * @param lastUpdateBlock Block number of last update
     */
    struct PoolLiquidityState {
        uint256 totalLiquidity;
        uint256 token0Reserves;
        uint256 token1Reserves;
        uint256 price;
        uint256 lastUpdateBlock;
    }

    /**
     * @notice Rebalancing calculation result
     * @param shouldRebalance Whether rebalancing should occur
     * @param rebalanceAmount Amount to rebalance (positive = add, negative = remove)
     * @param targetPrice Target price after rebalancing
     * @param expectedSlippage Expected slippage from rebalancing
     * @param gasCost Estimated gas cost
     * @param confidence Confidence in the calculation (0-100%)
     */
    struct RebalancingResult {
        bool shouldRebalance;
        int256 rebalanceAmount;
        uint256 targetPrice;
        uint256 expectedSlippage;
        uint256 gasCost;
        uint256 confidence;
    }

    /**
     * @notice Calculate optimal liquidity distribution across chains
     * @param chainStates Array of chain liquidity states
     * @param totalLiquidity Total liquidity across all chains
     * @param targetDistribution Target distribution percentages
     * @return optimalDistribution Optimal liquidity distribution
     * @return rebalancingAmounts Amounts to rebalance for each chain
     */
    function calculateOptimalDistribution(
        PoolLiquidityState[] memory chainStates,
        uint256 totalLiquidity,
        uint256[] memory targetDistribution
    ) internal pure returns (
        uint256[] memory optimalDistribution,
        int256[] memory rebalancingAmounts
    ) {
        require(chainStates.length > 0, "No chain states provided");
        require(chainStates.length == targetDistribution.length, "Mismatched array lengths");
        require(totalLiquidity > 0, "Total liquidity must be positive");
        
        uint256 chainCount = chainStates.length;
        optimalDistribution = new uint256[](chainCount);
        rebalancingAmounts = new int256[](chainCount);
        
        // Calculate current distribution
        uint256[] memory currentDistribution = new uint256[](chainCount);
        uint256 totalCurrentLiquidity = 0;
        
        for (uint256 i = 0; i < chainCount; i++) {
            currentDistribution[i] = chainStates[i].totalLiquidity;
            totalCurrentLiquidity += chainStates[i].totalLiquidity;
        }
        
        // Calculate optimal distribution based on target percentages
        for (uint256 i = 0; i < chainCount; i++) {
            optimalDistribution[i] = (totalLiquidity * targetDistribution[i]) / PRECISION;
        }
        
        // Calculate rebalancing amounts
        for (uint256 i = 0; i < chainCount; i++) {
            int256 currentAmount = int256(currentDistribution[i]);
            int256 optimalAmount = int256(optimalDistribution[i]);
            rebalancingAmounts[i] = optimalAmount - currentAmount;
        }
    }

    /**
     * @notice Calculate rebalancing decision for a specific chain
     * @param currentState Current pool state
     * @param globalState Global aggregated state
     * @param chainIndex Index of the chain in the global state
     * @param gasPrice Current gas price
     * @return result Rebalancing calculation result
     */
    function calculateRebalancingDecision(
        PoolLiquidityState memory currentState,
        PoolLiquidityState[] memory globalState,
        uint256 chainIndex,
        uint256 gasPrice
    ) internal view returns (RebalancingResult memory result) {
        require(chainIndex < globalState.length, "Invalid chain index");
        require(globalState.length > 1, "Need multiple chains for rebalancing");
        
        // Calculate global metrics
        uint256 totalGlobalLiquidity = 0;
        uint256 totalGlobalPrice = 0;
        uint256 validChains = 0;
        
        for (uint256 i = 0; i < globalState.length; i++) {
            if (globalState[i].totalLiquidity > 0) {
                totalGlobalLiquidity += globalState[i].totalLiquidity;
                totalGlobalPrice += globalState[i].price;
                validChains++;
            }
        }
        
        require(validChains > 1, "Need at least 2 valid chains");
        
        uint256 averageGlobalLiquidity = totalGlobalLiquidity / validChains;
        uint256 averageGlobalPrice = totalGlobalPrice / validChains;
        
        // Calculate current chain's deviation from average
        int256 liquidityDeviation = int256(currentState.totalLiquidity) - int256(averageGlobalLiquidity);
        uint256 priceDeviation = _abs(currentState.price, averageGlobalPrice);
        
        // Calculate imbalance percentage
        uint256 imbalancePercent = 0;
        if (averageGlobalLiquidity > 0) {
            imbalancePercent = (_abs(liquidityDeviation, 0) * PRECISION) / averageGlobalLiquidity;
        }
        
        // Determine if rebalancing is needed
        bool shouldRebalance = imbalancePercent > MIN_REBALANCING_THRESHOLD;
        
        // Calculate rebalancing amount
        int256 rebalanceAmount = 0;
        if (shouldRebalance) {
            // Move half of the deviation towards the average
            rebalanceAmount = liquidityDeviation / 2;
            
            // Cap rebalancing amount
            uint256 maxAmount = (currentState.totalLiquidity * MAX_REBALANCING_AMOUNT) / PRECISION;
            if (rebalanceAmount > 0) {
                rebalanceAmount = rebalanceAmount > int256(maxAmount) ? int256(maxAmount) : rebalanceAmount;
            } else {
                rebalanceAmount = rebalanceAmount < -int256(maxAmount) ? -int256(maxAmount) : rebalanceAmount;
            }
        }
        
        // Calculate target price (move towards global average)
        uint256 targetPrice = currentState.price;
        if (priceDeviation > 0 && averageGlobalPrice > 0) {
            // Move 30% towards global average
            uint256 priceAdjustment = (priceDeviation * 30) / 100;
            if (currentState.price > averageGlobalPrice) {
                targetPrice = currentState.price - priceAdjustment;
            } else {
                targetPrice = currentState.price + priceAdjustment;
            }
        }
        
        // Calculate expected slippage
        uint256 expectedSlippage = _calculateExpectedSlippage(
            currentState,
            rebalanceAmount,
            targetPrice
        );
        
        // Calculate gas cost
        uint256 gasCost = gasPrice * REBALANCING_GAS_COST;
        
        // Calculate confidence based on data quality and market conditions
        uint256 confidence = _calculateRebalancingConfidence(
            currentState,
            globalState,
            imbalancePercent,
            priceDeviation
        );
        
        return RebalancingResult({
            shouldRebalance: shouldRebalance,
            rebalanceAmount: rebalanceAmount,
            targetPrice: targetPrice,
            expectedSlippage: expectedSlippage,
            gasCost: gasCost,
            confidence: confidence
        });
    }

    /**
     * @notice Calculate optimal rebalancing path across multiple chains
     * @param chainStates Array of chain states
     * @param rebalancingAmounts Desired rebalancing amounts for each chain
     * @param gasPrices Gas prices for each chain
     * @return optimalPath Optimal rebalancing path
     * @return totalCost Total cost for rebalancing
     * @return totalSlippage Total expected slippage
     */
    function calculateOptimalRebalancingPath(
        PoolLiquidityState[] memory chainStates,
        int256[] memory rebalancingAmounts,
        uint256[] memory gasPrices
    ) internal pure returns (
        uint256[] memory optimalPath,
        uint256 totalCost,
        uint256 totalSlippage
    ) {
        require(chainStates.length == rebalancingAmounts.length, "Mismatched array lengths");
        require(chainStates.length == gasPrices.length, "Mismatched array lengths");
        require(chainStates.length > 1, "Need at least 2 chains");
        
        // Find chains that need liquidity (negative rebalancing amounts)
        uint256[] memory sourceChains = new uint256[](chainStates.length);
        uint256[] memory targetChains = new uint256[](chainStates.length);
        uint256 sourceCount = 0;
        uint256 targetCount = 0;
        
        for (uint256 i = 0; i < chainStates.length; i++) {
            if (rebalancingAmounts[i] < 0) {
                sourceChains[sourceCount] = i;
                sourceCount++;
            } else if (rebalancingAmounts[i] > 0) {
                targetChains[targetCount] = i;
                targetCount++;
            }
        }
        
        require(sourceCount > 0 && targetCount > 0, "No rebalancing needed");
        
        // Simple path: match sources with targets based on amount
        uint256[] memory path = new uint256[](sourceCount + targetCount);
        uint256 pathIndex = 0;
        
        // Add source chains
        for (uint256 i = 0; i < sourceCount; i++) {
            path[pathIndex] = sourceChains[i];
            pathIndex++;
        }
        
        // Add target chains
        for (uint256 i = 0; i < targetCount; i++) {
            path[pathIndex] = targetChains[i];
            pathIndex++;
        }
        
        optimalPath = path;
        
        // Calculate total cost and slippage
        totalCost = 0;
        totalSlippage = 0;
        
        for (uint256 i = 0; i < chainStates.length; i++) {
            if (rebalancingAmounts[i] != 0) {
                totalCost += gasPrices[i] * REBALANCING_GAS_COST;
                
                uint256 slippage = _calculateExpectedSlippage(
                    chainStates[i],
                    rebalancingAmounts[i],
                    chainStates[i].price
                );
                totalSlippage += slippage;
            }
        }
    }

    /**
     * @notice Calculate liquidity efficiency score
     * @param chainStates Array of chain states
     * @param targetDistribution Target distribution percentages
     * @return efficiencyScore Efficiency score (0-100%)
     * @return recommendations Array of improvement recommendations
     */
    function calculateLiquidityEfficiency(
        PoolLiquidityState[] memory chainStates,
        uint256[] memory targetDistribution
    ) internal pure returns (
        uint256 efficiencyScore,
        uint256[] memory recommendations
    ) {
        require(chainStates.length > 0, "No chain states provided");
        require(chainStates.length == targetDistribution.length, "Mismatched array lengths");
        
        uint256 totalLiquidity = 0;
        for (uint256 i = 0; i < chainStates.length; i++) {
            totalLiquidity += chainStates[i].totalLiquidity;
        }
        
        require(totalLiquidity > 0, "No liquidity available");
        
        // Calculate current distribution
        uint256[] memory currentDistribution = new uint256[](chainStates.length);
        for (uint256 i = 0; i < chainStates.length; i++) {
            currentDistribution[i] = (chainStates[i].totalLiquidity * PRECISION) / totalLiquidity;
        }
        
        // Calculate efficiency score based on deviation from target
        uint256 totalDeviation = 0;
        recommendations = new uint256[](chainStates.length);
        
        for (uint256 i = 0; i < chainStates.length; i++) {
            uint256 deviation = _abs(currentDistribution[i], targetDistribution[i]);
            totalDeviation += deviation;
            
            // Generate recommendations
            if (deviation > 10e16) { // More than 10% deviation
                recommendations[i] = 1; // High priority rebalancing
            } else if (deviation > 5e16) { // More than 5% deviation
                recommendations[i] = 2; // Medium priority rebalancing
            } else {
                recommendations[i] = 0; // No rebalancing needed
            }
        }
        
        // Calculate efficiency score (100% - average deviation)
        uint256 averageDeviation = totalDeviation / chainStates.length;
        efficiencyScore = averageDeviation > PRECISION ? 0 : PRECISION - averageDeviation;
    }

    /**
     * @notice Calculate optimal rebalancing frequency
     * @param historicalStates Array of historical chain states
     * @param rebalancingCosts Array of historical rebalancing costs
     * @return optimalFrequency Optimal rebalancing frequency in blocks
     * @return costBenefitRatio Cost-benefit ratio
     */
    function calculateOptimalRebalancingFrequency(
        PoolLiquidityState[][] memory historicalStates,
        uint256[] memory rebalancingCosts
    ) internal pure returns (
        uint256 optimalFrequency,
        uint256 costBenefitRatio
    ) {
        require(historicalStates.length > 0, "No historical data provided");
        require(historicalStates.length == rebalancingCosts.length, "Mismatched array lengths");
        
        // Calculate average imbalance over time
        uint256 totalImbalance = 0;
        uint256 totalCost = 0;
        
        for (uint256 i = 0; i < historicalStates.length; i++) {
            uint256 imbalance = _calculateImbalanceScore(historicalStates[i]);
            totalImbalance += imbalance;
            totalCost += rebalancingCosts[i];
        }
        
        uint256 averageImbalance = totalImbalance / historicalStates.length;
        uint256 averageCost = totalCost / historicalStates.length;
        
        // Calculate optimal frequency based on cost-benefit analysis
        if (averageImbalance > 20e16) { // High imbalance
            optimalFrequency = 100; // Rebalance every 100 blocks
        } else if (averageImbalance > 10e16) { // Medium imbalance
            optimalFrequency = 300; // Rebalance every 300 blocks
        } else { // Low imbalance
            optimalFrequency = 1000; // Rebalance every 1000 blocks
        }
        
        // Calculate cost-benefit ratio
        if (averageCost > 0) {
            costBenefitRatio = (averageImbalance * PRECISION) / averageCost;
        } else {
            costBenefitRatio = PRECISION;
        }
    }

    // ============ Internal Helper Functions ============

    function _abs(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function _abs(int256 a, int256 b) internal pure returns (uint256) {
        return a > b ? uint256(a - b) : uint256(b - a);
    }

    function _calculateExpectedSlippage(
        PoolLiquidityState memory state,
        int256 rebalanceAmount,
        uint256 targetPrice
    ) internal pure returns (uint256 slippage) {
        if (rebalanceAmount == 0 || state.totalLiquidity == 0) {
            return 0;
        }
        
        // Simplified slippage calculation
        uint256 amount = rebalanceAmount > 0 ? uint256(rebalanceAmount) : uint256(-rebalanceAmount);
        uint256 liquidityRatio = (amount * PRECISION) / state.totalLiquidity;
        
        // Slippage increases with the square of the liquidity ratio
        slippage = (liquidityRatio * liquidityRatio) / PRECISION;
        
        // Cap slippage at maximum threshold
        if (slippage > MAX_REBALANCING_SLIPPAGE) {
            slippage = MAX_REBALANCING_SLIPPAGE;
        }
    }

    function _calculateRebalancingConfidence(
        PoolLiquidityState memory currentState,
        PoolLiquidityState[] memory globalState,
        uint256 imbalancePercent,
        uint256 priceDeviation
    ) internal view returns (uint256 confidence) {
        // Base confidence
        confidence = 80e16; // 80%
        
        // Adjust for data freshness
        if (currentState.lastUpdateBlock > 0) {
            uint256 age = block.number - currentState.lastUpdateBlock;
            if (age > 100) { // More than 100 blocks old
                confidence = confidence * 9 / 10; // 10% penalty
            }
        }
        
        // Adjust for imbalance severity
        if (imbalancePercent > 30e16) { // More than 30% imbalance
            confidence = confidence * 12 / 10; // 20% bonus for high confidence
        } else if (imbalancePercent < 5e16) { // Less than 5% imbalance
            confidence = confidence * 8 / 10; // 20% penalty for low confidence
        }
        
        // Adjust for price deviation
        if (priceDeviation > 10e16) { // More than 10% price deviation
            confidence = confidence * 11 / 10; // 10% bonus
        }
        
        // Ensure within bounds
        confidence = confidence > PRECISION ? PRECISION : confidence;
        confidence = confidence < 30e16 ? 30e16 : confidence; // Minimum 30%
    }

    function _calculateImbalanceScore(
        PoolLiquidityState[] memory states
    ) internal pure returns (uint256 imbalanceScore) {
        if (states.length < 2) return 0;
        
        uint256 totalLiquidity = 0;
        for (uint256 i = 0; i < states.length; i++) {
            totalLiquidity += states[i].totalLiquidity;
        }
        
        if (totalLiquidity == 0) return 0;
        
        uint256 expectedLiquidityPerChain = totalLiquidity / states.length;
        uint256 maxDeviation = 0;
        
        for (uint256 i = 0; i < states.length; i++) {
            uint256 deviation = _abs(states[i].totalLiquidity, expectedLiquidityPerChain);
            if (deviation > maxDeviation) {
                maxDeviation = deviation;
            }
        }
        
        imbalanceScore = (maxDeviation * PRECISION) / expectedLiquidityPerChain;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

/**
 * @title StateCalculations
 * @notice Library for cross-chain state calculations and pool metrics
 * @dev Provides utilities for calculating liquidity, price, and imbalance metrics
 */
library StateCalculations {
    /// @notice Precision for calculations (18 decimals)
    uint256 public constant PRECISION = 1e18;
    
    /// @notice Maximum price deviation threshold (5%)
    uint256 public constant MAX_PRICE_DEVIATION = 5e16; // 5%
    
    /// @notice Maximum imbalance threshold (20%)
    uint256 public constant MAX_IMBALANCE_THRESHOLD = 20e16; // 20%
    
    /// @notice Minimum liquidity threshold to avoid division by zero
    uint256 public constant MIN_LIQUIDITY = 1e6; // 1 USDC worth

    /**
     * @notice Calculate pool state from current slot0 data
     * @param sqrtPriceX96 Current sqrt price from slot0
     * @param liquidity Current liquidity from slot0
     * @param tick Current tick from slot0
     * @return price Current price (token1/token0)
     * @return totalLiquidity Total liquidity in USD terms
     * @return priceImpact Estimated price impact for 1% swap
     */
    function calculatePoolState(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    ) internal pure returns (
        uint256 price,
        uint256 totalLiquidity,
        uint256 priceImpact
    ) {
        // Convert sqrt price to actual price
        price = _sqrtPriceToPrice(sqrtPriceX96);
        
        // Calculate total liquidity (simplified - assumes 1:1 token value)
        totalLiquidity = uint256(liquidity) * price / PRECISION;
        
        // Calculate price impact for 1% of liquidity
        if (liquidity > 0) {
            uint256 swapAmount = totalLiquidity / 100; // 1% of liquidity
            priceImpact = _calculatePriceImpact(swapAmount, liquidity, sqrtPriceX96);
        }
    }

    /**
     * @notice Calculate global state metrics from multiple chain states
     * @param chainStates Array of chain states
     * @param chainIds Array of corresponding chain IDs
     * @return totalLiquidity Sum of all chain liquidity
     * @return averagePrice Weighted average price across chains
     * @return imbalanceScore Maximum imbalance between chains
     * @return priceVariance Price variance across chains
     */
    function calculateGlobalMetrics(
        uint256[] memory chainStates, // [liquidity, price, liquidity, price, ...]
        uint256[] memory chainIds
    ) internal pure returns (
        uint256 totalLiquidity,
        uint256 averagePrice,
        uint256 imbalanceScore,
        uint256 priceVariance
    ) {
        require(chainStates.length == chainIds.length * 2, "Invalid state data");
        require(chainIds.length > 0, "No chain data");
        
        uint256 weightedPriceSum = 0;
        uint256 totalWeight = 0;
        uint256 maxImbalance = 0;
        uint256 priceSum = 0;
        uint256 priceCount = 0;
        
        // Calculate total liquidity and weighted average price
        for (uint256 i = 0; i < chainIds.length; i++) {
            uint256 liquidity = chainStates[i * 2];
            uint256 price = chainStates[i * 2 + 1];
            
            totalLiquidity += liquidity;
            weightedPriceSum += price * liquidity;
            totalWeight += liquidity;
            priceSum += price;
            priceCount++;
        }
        
        if (totalWeight > 0) {
            averagePrice = weightedPriceSum / totalWeight;
        }
        
        // Calculate imbalance score (max deviation from average)
        uint256 expectedLiquidityPerChain = totalLiquidity / chainIds.length;
        for (uint256 i = 0; i < chainIds.length; i++) {
            uint256 liquidity = chainStates[i * 2];
            uint256 deviation = _abs(liquidity, expectedLiquidityPerChain);
            uint256 imbalancePercent = (deviation * PRECISION) / expectedLiquidityPerChain;
            
            if (imbalancePercent > maxImbalance) {
                maxImbalance = imbalancePercent;
            }
        }
        
        imbalanceScore = maxImbalance;
        
        // Calculate price variance
        if (priceCount > 1) {
            uint256 meanPrice = priceSum / priceCount;
            uint256 varianceSum = 0;
            
            for (uint256 i = 0; i < chainIds.length; i++) {
                uint256 price = chainStates[i * 2 + 1];
                uint256 diff = _abs(price, meanPrice);
                varianceSum += (diff * diff) / PRECISION;
            }
            
            priceVariance = varianceSum / priceCount;
        }
    }

    /**
     * @notice Calculate optimal swap parameters based on global state
     * @param originalParams Original swap parameters
     * @param currentPrice Current local pool price
     * @param globalPrice Global average price
     * @param globalLiquidity Global total liquidity
     * @param localLiquidity Local pool liquidity
     * @param imbalanceScore Current global imbalance
     * @return adjustedParams Optimized swap parameters
     */
    function calculateOptimalSwapParams(
        SwapParams memory originalParams,
        uint256 currentPrice,
        uint256 globalPrice,
        uint256 globalLiquidity,
        uint256 localLiquidity,
        uint256 imbalanceScore
    ) internal pure returns (SwapParams memory adjustedParams) {
        adjustedParams = originalParams;
        
        // If local pool is over-liquid compared to global average
        uint256 expectedLocalLiquidity = globalLiquidity / 4; // Assuming 4 chains
        if (localLiquidity > expectedLocalLiquidity * 12 / 10) { // 20% over
            // Allow larger swaps with less impact
            adjustedParams.sqrtPriceLimitX96 = _adjustPriceLimit(
                originalParams.sqrtPriceLimitX96,
                -15 // Reduce price impact by 15%
            );
        }
        
        // If significant price deviation from global average
        uint256 priceDeviation = _abs(currentPrice, globalPrice);
        if (priceDeviation > MAX_PRICE_DEVIATION) {
            // Adjust towards global price
            adjustedParams.sqrtPriceLimitX96 = _adjustTowardsPrice(
                originalParams.sqrtPriceLimitX96,
                globalPrice,
                currentPrice
            );
        }
        
        // If high imbalance, encourage rebalancing
        if (imbalanceScore > MAX_IMBALANCE_THRESHOLD) {
            // Increase swap size to help rebalancing
            adjustedParams.amountSpecified = (originalParams.amountSpecified * 11) / 10; // 10% increase
        }
    }

    /**
     * @notice Check if rebalancing should be triggered
     * @param imbalanceScore Current imbalance score
     * @param priceVariance Current price variance
     * @param lastRebalanceBlock Block number of last rebalancing
     * @param currentBlock Current block number
     * @return shouldRebalance True if rebalancing should be triggered
     * @return urgencyLevel Urgency level (1-5, 5 being most urgent)
     */
    function shouldTriggerRebalancing(
        uint256 imbalanceScore,
        uint256 priceVariance,
        uint256 lastRebalanceBlock,
        uint256 currentBlock
    ) internal pure returns (bool shouldRebalance, uint256 urgencyLevel) {
        // High imbalance threshold
        if (imbalanceScore > MAX_IMBALANCE_THRESHOLD) {
            return (true, 5);
        }
        
        // High price variance
        if (priceVariance > MAX_PRICE_DEVIATION * 2) {
            return (true, 4);
        }
        
        // Medium imbalance with time factor
        if (imbalanceScore > MAX_IMBALANCE_THRESHOLD / 2 && 
            currentBlock - lastRebalanceBlock > 100) { // 100 blocks cooldown
            return (true, 3);
        }
        
        // Low urgency rebalancing
        if (imbalanceScore > MAX_IMBALANCE_THRESHOLD / 4 && 
            currentBlock - lastRebalanceBlock > 1000) { // 1000 blocks cooldown
            return (true, 2);
        }
        
        return (false, 0);
    }

    /**
     * @notice Calculate rebalancing amount for a specific chain
     * @param sourceLiquidity Source chain liquidity
     * @param targetLiquidity Target chain liquidity
     * @param totalLiquidity Total liquidity across all chains
     * @param chainCount Number of chains
     * @return rebalanceAmount Amount to rebalance (positive = send to target)
     */
    function calculateRebalancingAmount(
        uint256 sourceLiquidity,
        uint256 targetLiquidity,
        uint256 totalLiquidity,
        uint256 chainCount
    ) internal pure returns (int256 rebalanceAmount) {
        uint256 expectedLiquidityPerChain = totalLiquidity / chainCount;
        
        // Calculate how much source chain is over/under
        int256 sourceDeviation = int256(sourceLiquidity) - int256(expectedLiquidityPerChain);
        int256 targetDeviation = int256(targetLiquidity) - int256(expectedLiquidityPerChain);
        
        // If both chains are over/under, no rebalancing needed
        if ((sourceDeviation > 0 && targetDeviation > 0) || 
            (sourceDeviation < 0 && targetDeviation < 0)) {
            return 0;
        }
        
        // Calculate optimal rebalancing amount
        if (sourceDeviation > 0 && targetDeviation < 0) {
            // Source has excess, target needs liquidity
            rebalanceAmount = sourceDeviation / 2; // Move half of excess
        } else if (sourceDeviation < 0 && targetDeviation > 0) {
            // Target has excess, source needs liquidity
            rebalanceAmount = -targetDeviation / 2; // Move half of excess
        }
        
        // Ensure we don't over-rebalance
        if (rebalanceAmount > 0) {
            rebalanceAmount = rebalanceAmount > int256(sourceLiquidity / 2) ? 
                int256(sourceLiquidity / 2) : rebalanceAmount;
        } else if (rebalanceAmount < 0) {
            rebalanceAmount = rebalanceAmount < -int256(targetLiquidity / 2) ? 
                -int256(targetLiquidity / 2) : rebalanceAmount;
        }
    }

    // ============ Internal Helper Functions ============

    /**
     * @notice Convert sqrt price to actual price
     * @param sqrtPriceX96 Sqrt price in X96 format
     * @return price Actual price (token1/token0)
     */
    function _sqrtPriceToPrice(uint160 sqrtPriceX96) internal pure returns (uint256 price) {
        uint256 sqrtPrice = uint256(sqrtPriceX96);
        price = (sqrtPrice * sqrtPrice) >> (96 * 2);
    }

    /**
     * @notice Calculate price impact for a given swap amount
     * @param swapAmount Amount being swapped
     * @param liquidity Current pool liquidity
     * @param sqrtPriceX96 Current sqrt price
     * @return priceImpact Price impact as percentage (in PRECISION units)
     */
    function _calculatePriceImpact(
        uint256 swapAmount,
        uint128 liquidity,
        uint160 sqrtPriceX96
    ) internal pure returns (uint256 priceImpact) {
        if (liquidity == 0) return 0;
        
        // Simplified price impact calculation
        // In reality, this would use the Uniswap V4 tick math
        uint256 impact = (swapAmount * PRECISION) / uint256(liquidity);
        return impact > PRECISION ? PRECISION : impact;
    }

    /**
     * @notice Adjust price limit based on percentage change
     * @param originalPriceLimit Original price limit
     * @param percentChange Percentage change (in basis points, e.g., -15 for -15%)
     * @return adjustedPriceLimit Adjusted price limit
     */
    function _adjustPriceLimit(
        uint160 originalPriceLimit,
        int256 percentChange
    ) internal pure returns (uint160 adjustedPriceLimit) {
        if (percentChange == 0) return originalPriceLimit;
        
        uint256 adjustment = uint256(originalPriceLimit) * uint256(_abs(percentChange, 0)) / 10000;
        
        if (percentChange > 0) {
            adjustedPriceLimit = uint160(uint256(originalPriceLimit) + adjustment);
        } else {
            adjustedPriceLimit = uint160(uint256(originalPriceLimit) - adjustment);
        }
    }

    /**
     * @notice Adjust price limit towards a target price
     * @param originalPriceLimit Original price limit
     * @param targetPrice Target price to move towards
     * @param currentPrice Current price
     * @return adjustedPriceLimit Adjusted price limit
     */
    function _adjustTowardsPrice(
        uint160 originalPriceLimit,
        uint256 targetPrice,
        uint256 currentPrice
    ) internal pure returns (uint160 adjustedPriceLimit) {
        if (targetPrice == currentPrice) return originalPriceLimit;
        
        // Calculate 50% of the way towards target price
        uint256 targetSqrtPrice = _priceToSqrtPrice(targetPrice);
        uint256 currentSqrtPrice = _priceToSqrtPrice(currentPrice);
        
        uint256 adjustedSqrtPrice = currentSqrtPrice + (targetSqrtPrice - currentSqrtPrice) / 2;
        
        return uint160(adjustedSqrtPrice);
    }

    /**
     * @notice Convert price to sqrt price
     * @param price Price (token1/token0)
     * @return sqrtPrice Sqrt price in X96 format
     */
    function _priceToSqrtPrice(uint256 price) internal pure returns (uint256 sqrtPrice) {
        sqrtPrice = _sqrt(price * (1 << 192));
    }

    /**
     * @notice Calculate absolute difference between two numbers
     * @param a First number
     * @param b Second number
     * @return Absolute difference
     */
    function _abs(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    /**
     * @notice Calculate absolute difference between two signed numbers
     * @param a First number
     * @param b Second number
     * @return Absolute difference
     */
    function _abs(int256 a, int256 b) internal pure returns (uint256) {
        return a > b ? uint256(a - b) : uint256(b - a);
    }

    /**
     * @notice Calculate square root using Babylonian method
     * @param x Number to calculate square root of
     * @return sqrt Square root
     */
    function _sqrt(uint256 x) internal pure returns (uint256 sqrt) {
        if (x == 0) return 0;
        
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        
        return y;
    }
}

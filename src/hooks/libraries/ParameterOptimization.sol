// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {StateCalculations} from "./StateCalculations.sol";

/**
 * @title ParameterOptimization
 * @notice Library for optimizing swap parameters based on cross-chain state
 * @dev Provides intelligent parameter adjustment for better execution
 */
library ParameterOptimization {
    using StateCalculations for uint256;

    /// @notice Maximum slippage tolerance (5%)
    uint256 public constant MAX_SLIPPAGE = 5e16; // 5%
    
    /// @notice Minimum slippage tolerance (0.1%)
    uint256 public constant MIN_SLIPPAGE = 1e15; // 0.1%
    
    /// @notice Price impact threshold for adjustment (2%)
    uint256 public constant PRICE_IMPACT_THRESHOLD = 2e16; // 2%
    
    /// @notice Liquidity efficiency threshold (80%)
    uint256 public constant LIQUIDITY_EFFICIENCY_THRESHOLD = 80e16; // 80%

    /**
     * @notice Optimize swap parameters based on global state
     * @param originalParams Original swap parameters
     * @param globalState Global state data [totalLiquidity, averagePrice, imbalanceScore, lastUpdateBlock]
     * @param localState Local state data [liquidity, price, priceImpact]
     * @param chainCount Number of supported chains
     * @return optimizedParams Optimized swap parameters
     * @return optimizationFlags Flags indicating what was optimized
     */
    function optimizeSwapParameters(
        SwapParams memory originalParams,
        uint256[4] memory globalState, // [totalLiquidity, averagePrice, imbalanceScore, lastUpdateBlock]
        uint256[3] memory localState,  // [liquidity, price, priceImpact]
        uint256 chainCount
    ) internal pure returns (
        SwapParams memory optimizedParams,
        uint256 optimizationFlags
    ) {
        optimizedParams = originalParams;
        optimizationFlags = 0;
        
        uint256 totalLiquidity = globalState[0];
        uint256 averagePrice = globalState[1];
        uint256 imbalanceScore = globalState[2];
        uint256 localLiquidity = localState[0];
        uint256 localPrice = localState[1];
        uint256 localPriceImpact = localState[2];
        
        // 1. Optimize based on liquidity efficiency
        if (localLiquidity > 0 && totalLiquidity > 0) {
            uint256 expectedLiquidity = totalLiquidity / chainCount;
            uint256 liquidityRatio = (localLiquidity * 1e18) / expectedLiquidity;
            
            if (liquidityRatio > 12e17) { // 20% over-liquid
                // Allow larger swaps with less restrictive limits
                optimizedParams = _optimizeForOverLiquidity(optimizedParams, liquidityRatio);
                optimizationFlags |= 1; // Flag: Liquidity optimization
            } else if (liquidityRatio < 8e17) { // 20% under-liquid
                // Restrict swaps to preserve liquidity
                optimizedParams = _optimizeForUnderLiquidity(optimizedParams, liquidityRatio);
                optimizationFlags |= 2; // Flag: Liquidity preservation
            }
        }
        
        // 2. Optimize based on price deviation
        if (localPrice > 0 && averagePrice > 0) {
            uint256 priceDeviation = _calculatePriceDeviation(localPrice, averagePrice);
            
            if (priceDeviation > StateCalculations.MAX_PRICE_DEVIATION) {
                // Adjust towards global average price
                optimizedParams = _optimizeForPriceAlignment(optimizedParams, localPrice, averagePrice);
                optimizationFlags |= 4; // Flag: Price alignment
            }
        }
        
        // 3. Optimize based on global imbalance
        if (imbalanceScore > StateCalculations.MAX_IMBALANCE_THRESHOLD) {
            // Encourage rebalancing through larger swaps
            optimizedParams = _optimizeForRebalancing(optimizedParams, imbalanceScore);
            optimizationFlags |= 8; // Flag: Rebalancing optimization
        }
        
        // 4. Optimize based on price impact
        if (localPriceImpact > PRICE_IMPACT_THRESHOLD) {
            // Reduce swap size to minimize impact
            optimizedParams = _optimizeForPriceImpact(optimizedParams, localPriceImpact);
            optimizationFlags |= 16; // Flag: Price impact optimization
        }
        
        // 5. Apply final safety checks
        optimizedParams = _applySafetyChecks(optimizedParams);
    }

    /**
     * @notice Calculate optimal swap amount based on market conditions
     * @param originalAmount Original swap amount
     * @param globalLiquidity Global total liquidity
     * @param localLiquidity Local pool liquidity
     * @param imbalanceScore Current imbalance score
     * @param priceVolatility Price volatility metric
     * @return optimalAmount Optimized swap amount
     */
    function calculateOptimalSwapAmount(
        int256 originalAmount,
        uint256 globalLiquidity,
        uint256 localLiquidity,
        uint256 imbalanceScore,
        uint256 priceVolatility
    ) internal pure returns (int256 optimalAmount) {
        optimalAmount = originalAmount;
        
        // Base adjustment factor
        uint256 adjustmentFactor = 1e18; // 100%
        
        // Adjust based on liquidity ratio
        if (globalLiquidity > 0 && localLiquidity > 0) {
            uint256 expectedLiquidity = globalLiquidity / 4; // Assuming 4 chains
            uint256 liquidityRatio = (localLiquidity * 1e18) / expectedLiquidity;
            
            if (liquidityRatio > 12e17) { // Over-liquid
                adjustmentFactor = adjustmentFactor * 12 / 10; // Increase by 20%
            } else if (liquidityRatio < 8e17) { // Under-liquid
                adjustmentFactor = adjustmentFactor * 8 / 10; // Decrease by 20%
            }
        }
        
        // Adjust based on imbalance
        if (imbalanceScore > StateCalculations.MAX_IMBALANCE_THRESHOLD) {
            adjustmentFactor = adjustmentFactor * 11 / 10; // Increase by 10% for rebalancing
        }
        
        // Adjust based on volatility
        if (priceVolatility > 5e16) { // 5% volatility
            adjustmentFactor = adjustmentFactor * 9 / 10; // Decrease by 10% for high volatility
        }
        
        // Apply adjustment
        optimalAmount = (originalAmount * int256(adjustmentFactor)) / 1e18;
        
        // Ensure we don't exceed reasonable bounds
        if (originalAmount > 0) {
            optimalAmount = optimalAmount > originalAmount * 2 ? originalAmount * 2 : optimalAmount;
            optimalAmount = optimalAmount < originalAmount / 2 ? originalAmount / 2 : optimalAmount;
        } else {
            optimalAmount = optimalAmount < originalAmount * 2 ? originalAmount * 2 : optimalAmount;
            optimalAmount = optimalAmount > originalAmount / 2 ? originalAmount / 2 : optimalAmount;
        }
    }

    /**
     * @notice Calculate optimal price limit based on market conditions
     * @param originalPriceLimit Original price limit
     * @param currentPrice Current pool price
     * @param targetPrice Target price (global average)
     * @param volatility Price volatility
     * @param timeToDeadline Time remaining to deadline
     * @return optimalPriceLimit Optimized price limit
     */
    function calculateOptimalPriceLimit(
        uint160 originalPriceLimit,
        uint256 currentPrice,
        uint256 targetPrice,
        uint256 volatility,
        uint256 timeToDeadline
    ) internal pure returns (uint160 optimalPriceLimit) {
        optimalPriceLimit = originalPriceLimit;
        
        // Calculate base slippage tolerance
        uint256 baseSlippage = _calculateBaseSlippage(volatility, timeToDeadline);
        
        // Adjust for price alignment
        if (targetPrice > 0 && currentPrice > 0) {
            uint256 priceDeviation = _calculatePriceDeviation(currentPrice, targetPrice);
            
            if (priceDeviation > StateCalculations.MAX_PRICE_DEVIATION) {
                // Allow more slippage to reach target price
                baseSlippage = baseSlippage * 15 / 10; // Increase by 50%
            }
        }
        
        // Apply slippage tolerance
        optimalPriceLimit = _applySlippageTolerance(
            originalPriceLimit,
            currentPrice,
            baseSlippage
        );
        
        // Ensure within reasonable bounds
        optimalPriceLimit = _clampPriceLimit(optimalPriceLimit, currentPrice);
    }

    // ============ Internal Optimization Functions ============

    /**
     * @notice Optimize parameters for over-liquid pools
     */
    function _optimizeForOverLiquidity(
        SwapParams memory params,
        uint256 liquidityRatio
    ) internal pure returns (SwapParams memory) {
        // Allow larger swaps with less restrictive limits
        params.amountSpecified = (params.amountSpecified * 12) / 10; // 20% increase
        
        // Relax price limits
        params.sqrtPriceLimitX96 = _relaxPriceLimit(params.sqrtPriceLimitX96, 20);
        
        return params;
    }

    /**
     * @notice Optimize parameters for under-liquid pools
     */
    function _optimizeForUnderLiquidity(
        SwapParams memory params,
        uint256 liquidityRatio
    ) internal pure returns (SwapParams memory) {
        // Restrict swap size to preserve liquidity
        params.amountSpecified = (params.amountSpecified * 8) / 10; // 20% decrease
        
        // Tighten price limits
        params.sqrtPriceLimitX96 = _tightenPriceLimit(params.sqrtPriceLimitX96, 20);
        
        return params;
    }

    /**
     * @notice Optimize parameters for price alignment
     */
    function _optimizeForPriceAlignment(
        SwapParams memory params,
        uint256 currentPrice,
        uint256 targetPrice
    ) internal pure returns (SwapParams memory) {
        // Adjust price limit towards target
        params.sqrtPriceLimitX96 = _adjustTowardsTargetPrice(
            params.sqrtPriceLimitX96,
            currentPrice,
            targetPrice
        );
        
        return params;
    }

    /**
     * @notice Optimize parameters for rebalancing
     */
    function _optimizeForRebalancing(
        SwapParams memory params,
        uint256 imbalanceScore
    ) internal pure returns (SwapParams memory) {
        // Increase swap size to help rebalancing
        uint256 increasePercent = (imbalanceScore * 10) / 1e18; // Scale with imbalance
        increasePercent = increasePercent > 50 ? 50 : increasePercent; // Cap at 50%
        
        params.amountSpecified = (params.amountSpecified * int256(100 + increasePercent)) / 100;
        
        return params;
    }

    /**
     * @notice Optimize parameters for price impact
     */
    function _optimizeForPriceImpact(
        SwapParams memory params,
        uint256 priceImpact
    ) internal pure returns (SwapParams memory) {
        // Reduce swap size to minimize impact
        uint256 reductionPercent = (priceImpact * 20) / 1e18; // Scale with impact
        reductionPercent = reductionPercent > 50 ? 50 : reductionPercent; // Cap at 50%
        
        params.amountSpecified = (params.amountSpecified * int256(100 - reductionPercent)) / 100;
        
        return params;
    }

    /**
     * @notice Apply final safety checks
     */
    function _applySafetyChecks(
        SwapParams memory params
    ) internal pure returns (SwapParams memory) {
        // Ensure amount is not zero
        if (params.amountSpecified == 0) {
            params.amountSpecified = 1;
        }
        
        // Ensure price limit is reasonable
        if (params.sqrtPriceLimitX96 == 0) {
            params.sqrtPriceLimitX96 = 1;
        }
        
        return params;
    }

    // ============ Helper Functions ============

    function _calculatePriceDeviation(
        uint256 price1,
        uint256 price2
    ) internal pure returns (uint256 deviation) {
        if (price1 == 0 || price2 == 0) return 0;
        
        uint256 diff = price1 > price2 ? price1 - price2 : price2 - price1;
        return (diff * 1e18) / price2;
    }

    function _calculateBaseSlippage(
        uint256 volatility,
        uint256 timeToDeadline
    ) internal pure returns (uint256 slippage) {
        // Base slippage from volatility
        slippage = volatility / 2; // Half of volatility
        
        // Adjust for time to deadline
        if (timeToDeadline < 300) { // Less than 5 minutes
            slippage = slippage * 12 / 10; // Increase by 20%
        } else if (timeToDeadline > 3600) { // More than 1 hour
            slippage = slippage * 8 / 10; // Decrease by 20%
        }
        
        // Ensure within bounds
        slippage = slippage > MAX_SLIPPAGE ? MAX_SLIPPAGE : slippage;
        slippage = slippage < MIN_SLIPPAGE ? MIN_SLIPPAGE : slippage;
    }

    function _applySlippageTolerance(
        uint160 originalPriceLimit,
        uint256 currentPrice,
        uint256 slippage
    ) internal pure returns (uint160) {
        // Convert current price to sqrt price
        uint256 currentSqrtPrice = _priceToSqrtPrice(currentPrice);
        
        // Apply slippage
        uint256 slippageAmount = (currentSqrtPrice * slippage) / 1e18;
        
        if (originalPriceLimit > currentSqrtPrice) {
            // Price going up - reduce limit
            return uint160(currentSqrtPrice + slippageAmount);
        } else {
            // Price going down - increase limit
            return uint160(currentSqrtPrice - slippageAmount);
        }
    }

    function _clampPriceLimit(
        uint160 priceLimit,
        uint256 currentPrice
    ) internal pure returns (uint160) {
        uint256 currentSqrtPrice = _priceToSqrtPrice(currentPrice);
        uint256 maxDeviation = (currentSqrtPrice * MAX_SLIPPAGE) / 1e18;
        
        uint256 minLimit = currentSqrtPrice > maxDeviation ? 
            currentSqrtPrice - maxDeviation : 1;
        uint256 maxLimit = currentSqrtPrice + maxDeviation;
        
        if (priceLimit < minLimit) return uint160(minLimit);
        if (priceLimit > maxLimit) return uint160(maxLimit);
        return priceLimit;
    }

    function _relaxPriceLimit(
        uint160 priceLimit,
        uint256 percent
    ) internal pure returns (uint160) {
        uint256 adjustment = (uint256(priceLimit) * percent) / 100;
        return uint160(uint256(priceLimit) + adjustment);
    }

    function _tightenPriceLimit(
        uint160 priceLimit,
        uint256 percent
    ) internal pure returns (uint160) {
        uint256 adjustment = (uint256(priceLimit) * percent) / 100;
        return uint160(uint256(priceLimit) - adjustment);
    }

    function _adjustTowardsTargetPrice(
        uint160 currentPriceLimit,
        uint256 currentPrice,
        uint256 targetPrice
    ) internal pure returns (uint160) {
        if (targetPrice == 0 || currentPrice == 0) return currentPriceLimit;
        
        uint256 currentSqrtPrice = _priceToSqrtPrice(currentPrice);
        uint256 targetSqrtPrice = _priceToSqrtPrice(targetPrice);
        
        // Move 30% towards target
        uint256 adjustedSqrtPrice = currentSqrtPrice + 
            (targetSqrtPrice - currentSqrtPrice) * 30 / 100;
        
        return uint160(adjustedSqrtPrice);
    }

    function _priceToSqrtPrice(uint256 price) internal pure returns (uint256) {
        return _sqrt(price * (1 << 192));
    }

    function _sqrt(uint256 x) internal pure returns (uint256) {
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

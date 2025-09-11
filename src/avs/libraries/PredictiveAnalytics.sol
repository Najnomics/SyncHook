// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {StateAggregation} from "./StateAggregation.sol";

/**
 * @title PredictiveAnalytics
 * @notice Library for predictive analytics and AI-driven optimization
 * @dev Provides machine learning-inspired algorithms for market prediction
 */
library PredictiveAnalytics {
    using StateAggregation for StateAggregation.ChainState;
    using StateAggregation for StateAggregation.AggregatedState;

    /// @notice Precision for calculations (18 decimals)
    uint256 public constant PRECISION = 1e18;
    
    /// @notice Maximum prediction horizon (24 hours in blocks)
    uint256 public constant MAX_PREDICTION_HORIZON = 7200; // 24 hours at 12s blocks
    
    /// @notice Minimum data points for prediction
    uint256 public constant MIN_DATA_POINTS = 10;
    
    /// @notice Confidence threshold for predictions (70%)
    uint256 public constant MIN_PREDICTION_CONFIDENCE = 70e16; // 70%

    /**
     * @notice Prediction result structure
     * @param predictedValue Predicted value
     * @param confidence Confidence in prediction (0-100%)
     * @param trendDirection Trend direction (1 = up, -1 = down, 0 = stable)
     * @param volatility Expected volatility
     * @param timeHorizon Prediction time horizon in blocks
     */
    struct PredictionResult {
        uint256 predictedValue;
        uint256 confidence;
        int256 trendDirection;
        uint256 volatility;
        uint256 timeHorizon;
    }

    /**
     * @notice Market trend analysis
     * @param trendType Type of trend (1 = bullish, -1 = bearish, 0 = sideways)
     * @param strength Trend strength (0-100%)
     * @param duration Expected trend duration in blocks
     * @param confidence Confidence in trend analysis
     */
    struct TrendAnalysis {
        int256 trendType;
        uint256 strength;
        uint256 duration;
        uint256 confidence;
    }

    /**
     * @notice Predict future price based on historical data
     * @param historicalStates Array of historical chain states
     * @param timeHorizon Prediction horizon in blocks
     * @return prediction Price prediction result
     */
    function predictPrice(
        StateAggregation.ChainState[] memory historicalStates,
        uint256 timeHorizon
    ) internal pure returns (PredictionResult memory prediction) {
        require(historicalStates.length >= MIN_DATA_POINTS, "Insufficient data");
        require(timeHorizon <= MAX_PREDICTION_HORIZON, "Horizon too far");
        
        // Extract price data
        uint256[] memory prices = new uint256[](historicalStates.length);
        uint256[] memory timestamps = new uint256[](historicalStates.length);
        uint256 validCount = 0;
        
        for (uint256 i = 0; i < historicalStates.length; i++) {
            if (historicalStates[i].isValid && historicalStates[i].price > 0) {
                prices[validCount] = historicalStates[i].price;
                timestamps[validCount] = historicalStates[i].lastUpdateBlock;
                validCount++;
            }
        }
        
        require(validCount >= MIN_DATA_POINTS, "Insufficient valid data");
        
        // Calculate trend using linear regression
        (int256 slope, uint256 rSquared) = _calculateLinearRegression(prices, timestamps, validCount);
        
        // Predict future price
        uint256 currentPrice = prices[validCount - 1];
        uint256 currentTime = timestamps[validCount - 1];
        uint256 futureTime = currentTime + timeHorizon;
        
        uint256 predictedPrice = currentPrice + uint256(slope) * timeHorizon;
        
        // Calculate confidence based on R-squared and data quality
        uint256 confidence = _calculatePredictionConfidence(rSquared, validCount, timeHorizon);
        
        // Calculate volatility
        uint256 volatility = _calculateVolatility(prices, validCount);
        
        // Determine trend direction
        int256 trendDirection = slope > 0 ? int256(1) : (slope < 0 ? int256(-1) : int256(0));
        
        return PredictionResult({
            predictedValue: predictedPrice,
            confidence: confidence,
            trendDirection: trendDirection,
            volatility: volatility,
            timeHorizon: timeHorizon
        });
    }

    /**
     * @notice Predict future liquidity based on historical data
     * @param historicalStates Array of historical chain states
     * @param timeHorizon Prediction horizon in blocks
     * @return prediction Liquidity prediction result
     */
    function predictLiquidity(
        StateAggregation.ChainState[] memory historicalStates,
        uint256 timeHorizon
    ) internal pure returns (PredictionResult memory prediction) {
        require(historicalStates.length >= MIN_DATA_POINTS, "Insufficient data");
        require(timeHorizon <= MAX_PREDICTION_HORIZON, "Horizon too far");
        
        // Extract liquidity data
        uint256[] memory liquidities = new uint256[](historicalStates.length);
        uint256[] memory timestamps = new uint256[](historicalStates.length);
        uint256 validCount = 0;
        
        for (uint256 i = 0; i < historicalStates.length; i++) {
            if (historicalStates[i].isValid && historicalStates[i].liquidity > 0) {
                liquidities[validCount] = historicalStates[i].liquidity;
                timestamps[validCount] = historicalStates[i].lastUpdateBlock;
                validCount++;
            }
        }
        
        require(validCount >= MIN_DATA_POINTS, "Insufficient valid data");
        
        // Calculate trend using linear regression
        (int256 slope, uint256 rSquared) = _calculateLinearRegression(liquidities, timestamps, validCount);
        
        // Predict future liquidity
        uint256 currentLiquidity = liquidities[validCount - 1];
        uint256 currentTime = timestamps[validCount - 1];
        uint256 futureTime = currentTime + timeHorizon;
        
        uint256 predictedLiquidity = currentLiquidity + uint256(slope) * timeHorizon;
        
        // Ensure non-negative liquidity
        if (predictedLiquidity > currentLiquidity * 2) {
            predictedLiquidity = currentLiquidity * 2; // Cap at 2x current
        }
        
        // Calculate confidence
        uint256 confidence = _calculatePredictionConfidence(rSquared, validCount, timeHorizon);
        
        // Calculate volatility
        uint256 volatility = _calculateVolatility(liquidities, validCount);
        
        // Determine trend direction
        int256 trendDirection = slope > 0 ? int256(1) : (slope < 0 ? int256(-1) : int256(0));
        
        return PredictionResult({
            predictedValue: predictedLiquidity,
            confidence: confidence,
            trendDirection: trendDirection,
            volatility: volatility,
            timeHorizon: timeHorizon
        });
    }

    /**
     * @notice Analyze market trends across multiple chains
     * @param chainStates Array of current chain states
     * @param historicalStates Array of historical states
     * @return trendAnalysis Market trend analysis
     */
    function analyzeMarketTrends(
        StateAggregation.ChainState[] memory chainStates,
        StateAggregation.ChainState[] memory historicalStates
    ) internal pure returns (TrendAnalysis memory trendAnalysis) {
        require(chainStates.length > 0, "No chain states provided");
        
        // Calculate overall trend strength
        uint256 totalTrendStrength = 0;
        uint256 validChains = 0;
        int256 overallTrend = 0;
        
        for (uint256 i = 0; i < chainStates.length; i++) {
            if (chainStates[i].isValid) {
                // Get historical data for this chain
                uint256[] memory chainPrices = _extractChainPrices(chainStates[i].chainId, historicalStates);
                
                if (chainPrices.length >= MIN_DATA_POINTS) {
                    // Calculate trend for this chain
                    (int256 chainTrend, uint256 chainStrength) = _calculateChainTrend(chainPrices);
                    
                    totalTrendStrength += chainStrength;
                    overallTrend += chainTrend;
                    validChains++;
                }
            }
        }
        
        require(validChains > 0, "No valid chains for trend analysis");
        
        // Calculate average trend strength
        uint256 averageTrendStrength = totalTrendStrength / validChains;
        
        // Determine overall trend direction
        int256 averageTrend = overallTrend / int256(validChains);
        int256 trendType = averageTrend > 1e16 ? int256(1) : (averageTrend < -1e16 ? int256(-1) : int256(0));
        
        // Calculate confidence based on consistency across chains
        uint256 confidence = _calculateTrendConfidence(chainStates, historicalStates);
        
        // Estimate trend duration based on historical patterns
        uint256 duration = _estimateTrendDuration(historicalStates);
        
        return TrendAnalysis({
            trendType: trendType,
            strength: averageTrendStrength,
            duration: duration,
            confidence: confidence
        });
    }

    /**
     * @notice Predict optimal rebalancing timing
     * @param currentStates Current chain states
     * @param historicalStates Historical states
     * @param timeHorizon Prediction horizon
     * @return optimalTiming Optimal timing for rebalancing (in blocks)
     * @return confidence Confidence in timing prediction
     */
    function predictOptimalRebalancingTiming(
        StateAggregation.ChainState[] memory currentStates,
        StateAggregation.ChainState[] memory historicalStates,
        uint256 timeHorizon
    ) internal pure returns (uint256 optimalTiming, uint256 confidence) {
        require(currentStates.length > 1, "Need multiple chains for rebalancing");
        require(timeHorizon <= MAX_PREDICTION_HORIZON, "Horizon too far");
        
        // Calculate current imbalance
        uint256 totalLiquidity = 0;
        uint256 validChains = 0;
        
        for (uint256 i = 0; i < currentStates.length; i++) {
            if (currentStates[i].isValid) {
                totalLiquidity += currentStates[i].liquidity;
                validChains++;
            }
        }
        
        require(validChains > 1, "Need at least 2 valid chains");
        
        uint256 expectedLiquidityPerChain = totalLiquidity / validChains;
        uint256 currentImbalance = _calculateImbalance(currentStates, expectedLiquidityPerChain);
        
        // Predict future imbalance trends
        uint256[] memory futureImbalances = new uint256[](timeHorizon / 100); // Check every 100 blocks
        uint256 checkCount = 0;
        
        for (uint256 blockOffset = 100; blockOffset <= timeHorizon; blockOffset += 100) {
            uint256 predictedImbalance = _predictImbalanceAtTime(
                currentStates,
                historicalStates,
                blockOffset
            );
            
            futureImbalances[checkCount] = predictedImbalance;
            checkCount++;
        }
        
        // Find optimal timing (minimum predicted imbalance)
        uint256 minImbalance = currentImbalance;
        uint256 optimalBlock = 0;
        
        for (uint256 i = 0; i < checkCount; i++) {
            if (futureImbalances[i] < minImbalance) {
                minImbalance = futureImbalances[i];
                optimalBlock = (i + 1) * 100;
            }
        }
        
        // Calculate confidence based on prediction quality
        confidence = _calculateTimingConfidence(currentStates, historicalStates, timeHorizon);
        
        return (optimalBlock, confidence);
    }

    // ============ Internal Helper Functions ============

    function _calculateLinearRegression(
        uint256[] memory values,
        uint256[] memory timestamps,
        uint256 count
    ) internal pure returns (int256 slope, uint256 rSquared) {
        require(count >= 2, "Need at least 2 data points");
        
        // Calculate means
        uint256 sumValues = 0;
        uint256 sumTimes = 0;
        
        for (uint256 i = 0; i < count; i++) {
            sumValues += values[i];
            sumTimes += timestamps[i];
        }
        
        uint256 meanValue = sumValues / count;
        uint256 meanTime = sumTimes / count;
        
        // Calculate slope and R-squared
        int256 numerator = 0;
        uint256 denominator = 0;
        uint256 ssRes = 0;
        uint256 ssTot = 0;
        
        for (uint256 i = 0; i < count; i++) {
            int256 timeDiff = int256(timestamps[i]) - int256(meanTime);
            int256 valueDiff = int256(values[i]) - int256(meanValue);
            
            numerator += timeDiff * valueDiff;
            denominator += uint256(timeDiff * timeDiff);
            
            ssTot += uint256(valueDiff * valueDiff);
        }
        
        if (denominator > 0) {
            slope = numerator / int256(denominator);
        }
        
        // Calculate R-squared
        for (uint256 i = 0; i < count; i++) {
            int256 predicted = int256(meanValue) + slope * (int256(timestamps[i]) - int256(meanTime));
            int256 residual = int256(values[i]) - predicted;
            ssRes += uint256(residual * residual);
        }
        
        rSquared = ssTot > 0 ? ((ssTot - ssRes) * PRECISION) / ssTot : 0;
    }

    function _calculatePredictionConfidence(
        uint256 rSquared,
        uint256 dataPoints,
        uint256 timeHorizon
    ) internal pure returns (uint256 confidence) {
        // Base confidence from R-squared
        confidence = rSquared;
        
        // Adjust for data quality
        if (dataPoints >= 50) {
            confidence = confidence * 11 / 10; // 10% bonus
        } else if (dataPoints < 20) {
            confidence = confidence * 9 / 10; // 10% penalty
        }
        
        // Adjust for time horizon (longer = less confident)
        uint256 horizonPenalty = (timeHorizon * 1e16) / MAX_PREDICTION_HORIZON;
        confidence = confidence > horizonPenalty ? confidence - horizonPenalty : 0;
        
        // Ensure within bounds
        confidence = confidence > PRECISION ? PRECISION : confidence;
        confidence = confidence < MIN_PREDICTION_CONFIDENCE ? MIN_PREDICTION_CONFIDENCE : confidence;
    }

    function _calculateVolatility(
        uint256[] memory values,
        uint256 count
    ) internal pure returns (uint256 volatility) {
        if (count < 2) return 0;
        
        // Calculate mean
        uint256 sum = 0;
        for (uint256 i = 0; i < count; i++) {
            sum += values[i];
        }
        uint256 mean = sum / count;
        
        // Calculate variance
        uint256 variance = 0;
        for (uint256 i = 0; i < count; i++) {
            uint256 diff = values[i] > mean ? values[i] - mean : mean - values[i];
            variance += (diff * diff) / PRECISION;
        }
        
        volatility = variance / count;
    }

    function _extractChainPrices(
        uint256 chainId,
        StateAggregation.ChainState[] memory historicalStates
    ) internal pure returns (uint256[] memory prices) {
        // Count valid prices for this chain
        uint256 validCount = 0;
        for (uint256 i = 0; i < historicalStates.length; i++) {
            if (historicalStates[i].chainId == chainId && 
                historicalStates[i].isValid && 
                historicalStates[i].price > 0) {
                validCount++;
            }
        }
        
        // Extract prices
        prices = new uint256[](validCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < historicalStates.length; i++) {
            if (historicalStates[i].chainId == chainId && 
                historicalStates[i].isValid && 
                historicalStates[i].price > 0) {
                prices[index] = historicalStates[i].price;
                index++;
            }
        }
    }

    function _calculateChainTrend(
        uint256[] memory prices
    ) internal pure returns (int256 trend, uint256 strength) {
        if (prices.length < 2) return (0, 0);
        
        // Simple trend calculation
        uint256 firstPrice = prices[0];
        uint256 lastPrice = prices[prices.length - 1];
        
        if (firstPrice > 0) {
            int256 priceChange = int256(lastPrice) - int256(firstPrice);
            trend = (priceChange * int256(PRECISION)) / int256(firstPrice);
        }
        
        // Calculate trend strength based on consistency
        uint256 consistentMoves = 0;
        for (uint256 i = 1; i < prices.length; i++) {
            if ((prices[i] > prices[i-1] && trend > 0) || 
                (prices[i] < prices[i-1] && trend < 0)) {
                consistentMoves++;
            }
        }
        
        strength = (consistentMoves * PRECISION) / (prices.length - 1);
    }

    function _calculateTrendConfidence(
        StateAggregation.ChainState[] memory currentStates,
        StateAggregation.ChainState[] memory historicalStates
    ) internal pure returns (uint256 confidence) {
        // Calculate consistency across chains
        uint256 totalConfidence = 0;
        uint256 validChains = 0;
        
        for (uint256 i = 0; i < currentStates.length; i++) {
            if (currentStates[i].isValid) {
                totalConfidence += currentStates[i].confidence;
                validChains++;
            }
        }
        
        if (validChains > 0) {
            confidence = totalConfidence / validChains;
        }
    }

    function _estimateTrendDuration(
        StateAggregation.ChainState[] memory historicalStates
    ) internal pure returns (uint256 duration) {
        // Simple duration estimation based on historical patterns
        // In a real implementation, this would use more sophisticated analysis
        return 1000; // Default 1000 blocks (~3.3 hours)
    }

    function _calculateImbalance(
        StateAggregation.ChainState[] memory states,
        uint256 expectedLiquidityPerChain
    ) internal pure returns (uint256 imbalance) {
        uint256 maxDeviation = 0;
        
        for (uint256 i = 0; i < states.length; i++) {
            if (states[i].isValid) {
                uint256 deviation = states[i].liquidity > expectedLiquidityPerChain ?
                    states[i].liquidity - expectedLiquidityPerChain :
                    expectedLiquidityPerChain - states[i].liquidity;
                
                if (deviation > maxDeviation) {
                    maxDeviation = deviation;
                }
            }
        }
        
        imbalance = (maxDeviation * PRECISION) / expectedLiquidityPerChain;
    }

    function _predictImbalanceAtTime(
        StateAggregation.ChainState[] memory currentStates,
        StateAggregation.ChainState[] memory historicalStates,
        uint256 blockOffset
    ) internal pure returns (uint256 predictedImbalance) {
        // Simplified prediction - in reality would use more sophisticated models
        uint256 currentImbalance = _calculateCurrentImbalance(currentStates);
        
        // Assume imbalance tends to increase over time without intervention
        uint256 timeFactor = (blockOffset * 1e16) / 1000; // 1% per 1000 blocks
        predictedImbalance = currentImbalance + timeFactor;
    }

    function _calculateCurrentImbalance(
        StateAggregation.ChainState[] memory states
    ) internal pure returns (uint256 imbalance) {
        uint256 totalLiquidity = 0;
        uint256 validChains = 0;
        
        for (uint256 i = 0; i < states.length; i++) {
            if (states[i].isValid) {
                totalLiquidity += states[i].liquidity;
                validChains++;
            }
        }
        
        if (validChains > 1) {
            uint256 expectedLiquidityPerChain = totalLiquidity / validChains;
            imbalance = _calculateImbalance(states, expectedLiquidityPerChain);
        }
    }

    function _calculateTimingConfidence(
        StateAggregation.ChainState[] memory currentStates,
        StateAggregation.ChainState[] memory historicalStates,
        uint256 timeHorizon
    ) internal pure returns (uint256 confidence) {
        // Base confidence on data quality and prediction horizon
        confidence = 80e16; // Start with 80%
        
        // Adjust for data availability
        if (historicalStates.length < 50) {
            confidence = confidence * 9 / 10; // 10% penalty
        }
        
        // Adjust for time horizon
        uint256 horizonPenalty = (timeHorizon * 1e16) / MAX_PREDICTION_HORIZON;
        confidence = confidence > horizonPenalty ? confidence - horizonPenalty : 0;
        
        // Ensure minimum confidence
        confidence = confidence < 30e16 ? 30e16 : confidence;
    }
}

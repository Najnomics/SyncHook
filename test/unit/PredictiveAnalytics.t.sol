// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PredictiveAnalytics} from "../../src/avs/libraries/PredictiveAnalytics.sol";
import {StateAggregation} from "../../src/avs/libraries/StateAggregation.sol";

// Wrapper contract to test internal functions
contract PredictiveAnalyticsWrapper {
    using StateAggregation for StateAggregation.ChainState;
    
    function predictPrice(
        StateAggregation.ChainState[] memory historicalStates,
        uint256 timeHorizon
    ) external pure returns (PredictiveAnalytics.PredictionResult memory) {
        return PredictiveAnalytics.predictPrice(historicalStates, timeHorizon);
    }
    
    function predictLiquidity(
        StateAggregation.ChainState[] memory historicalStates,
        uint256 timeHorizon
    ) external pure returns (PredictiveAnalytics.PredictionResult memory) {
        return PredictiveAnalytics.predictLiquidity(historicalStates, timeHorizon);
    }
    
    function analyzeMarketTrends(
        StateAggregation.ChainState[] memory chainStates,
        StateAggregation.ChainState[] memory historicalStates
    ) external pure returns (PredictiveAnalytics.TrendAnalysis memory) {
        return PredictiveAnalytics.analyzeMarketTrends(chainStates, historicalStates);
    }
    
    function predictOptimalRebalancingTiming(
        StateAggregation.ChainState[] memory currentStates,
        StateAggregation.ChainState[] memory historicalStates,
        uint256 timeHorizon
    ) external pure returns (uint256 optimalTiming, uint256 confidence) {
        return PredictiveAnalytics.predictOptimalRebalancingTiming(currentStates, historicalStates, timeHorizon);
    }
}

contract PredictiveAnalyticsTest is Test {
    using StateAggregation for StateAggregation.ChainState;
    using StateAggregation for StateAggregation.AggregatedState;
    
    PredictiveAnalyticsWrapper wrapper;

    // Test data
    StateAggregation.ChainState[] private historicalStates;
    StateAggregation.ChainState[] private currentStates;

    function setUp() public {
        wrapper = new PredictiveAnalyticsWrapper();
        
        // Create historical states for testing
        historicalStates = new StateAggregation.ChainState[](15);
        
        // Create ascending price trend
        for (uint256 i = 0; i < 15; i++) {
            historicalStates[i] = StateAggregation.ChainState({
                chainId: 1,
                liquidity: 1000000e18 + (i * 10000e18), // Increasing liquidity
                price: 2000e18 + (i * 10e18), // Increasing price
                volume24h: 50000e18,
                lastUpdateBlock: 1000 + i * 10,
                confidence: 90e16,
                isValid: true
            });
        }

        // Create current states
        currentStates = new StateAggregation.ChainState[](3);
        currentStates[0] = StateAggregation.ChainState({
            chainId: 1,
            liquidity: 1200000e18,
            price: 2150e18,
            volume24h: 60000e18,
            lastUpdateBlock: 1200,
            confidence: 95e16,
            isValid: true
        });
        currentStates[1] = StateAggregation.ChainState({
            chainId: 42161,
            liquidity: 1100000e18,
            price: 2140e18,
            volume24h: 55000e18,
            lastUpdateBlock: 1200,
            confidence: 92e16,
            isValid: true
        });
        currentStates[2] = StateAggregation.ChainState({
            chainId: 137,
            liquidity: 1300000e18,
            price: 2160e18,
            volume24h: 65000e18,
            lastUpdateBlock: 1200,
            confidence: 88e16,
            isValid: true
        });
    }

    function testPredictPrice() public {
        uint256 timeHorizon = 100;
        
        PredictiveAnalytics.PredictionResult memory result = wrapper.predictPrice(
            historicalStates,
            timeHorizon
        );
        
        assertTrue(result.predictedValue > 0, "Predicted value should be positive");
        assertTrue(result.confidence >= PredictiveAnalytics.MIN_PREDICTION_CONFIDENCE, "Confidence should meet minimum threshold");
        assertTrue(result.trendDirection >= -1 && result.trendDirection <= 1, "Trend direction should be valid");
        assertTrue(result.volatility >= 0, "Volatility should be non-negative");
        assertEq(result.timeHorizon, timeHorizon, "Time horizon should match input");
        
        console.log("Predicted price:", result.predictedValue);
        console.log("Confidence:", result.confidence);
        console.log("Trend direction:", result.trendDirection);
        console.log("Volatility:", result.volatility);
    }

    function testPredictLiquidity() public {
        uint256 timeHorizon = 200;
        
        PredictiveAnalytics.PredictionResult memory result = wrapper.predictLiquidity(
            historicalStates,
            timeHorizon
        );
        
        assertTrue(result.predictedValue > 0, "Predicted liquidity should be positive");
        assertTrue(result.confidence >= PredictiveAnalytics.MIN_PREDICTION_CONFIDENCE, "Confidence should meet minimum threshold");
        assertTrue(result.trendDirection >= -1 && result.trendDirection <= 1, "Trend direction should be valid");
        assertTrue(result.volatility >= 0, "Volatility should be non-negative");
        assertEq(result.timeHorizon, timeHorizon, "Time horizon should match input");
        
        console.log("Predicted liquidity:", result.predictedValue);
        console.log("Confidence:", result.confidence);
    }

    function testAnalyzeMarketTrends() public {
        PredictiveAnalytics.TrendAnalysis memory analysis = wrapper.analyzeMarketTrends(
            currentStates,
            historicalStates
        );
        
        assertTrue(analysis.trendType >= -1 && analysis.trendType <= 1, "Trend type should be valid");
        assertTrue(analysis.strength >= 0 && analysis.strength <= 1e18, "Strength should be between 0 and 100%");
        assertTrue(analysis.duration > 0, "Duration should be positive");
        assertTrue(analysis.confidence >= 0 && analysis.confidence <= 1e18, "Confidence should be between 0 and 100%");
        
        console.log("Trend type:", analysis.trendType);
        console.log("Strength:", analysis.strength);
        console.log("Duration:", analysis.duration);
        console.log("Confidence:", analysis.confidence);
    }

    function testPredictOptimalRebalancingTiming() public {
        uint256 timeHorizon = 500;
        
        (uint256 optimalTiming, uint256 confidence) = wrapper.predictOptimalRebalancingTiming(
            currentStates,
            historicalStates,
            timeHorizon
        );
        
        assertTrue(optimalTiming <= timeHorizon, "Optimal timing should be within horizon");
        assertTrue(confidence >= 0 && confidence <= 1e18, "Confidence should be between 0 and 100%");
        
        console.log("Optimal timing:", optimalTiming);
        console.log("Confidence:", confidence);
    }

    function testPredictPriceInsufficientData() public {
        StateAggregation.ChainState[] memory insufficientStates = new StateAggregation.ChainState[](5);
        
        for (uint256 i = 0; i < 5; i++) {
            insufficientStates[i] = StateAggregation.ChainState({
                chainId: 1,
                liquidity: 1000000e18,
                price: 2000e18,
                volume24h: 50000e18,
                lastUpdateBlock: 1000 + i * 10,
                confidence: 90e16,
                isValid: true
            });
        }
        
        vm.expectRevert("Insufficient data");
        wrapper.predictPrice(insufficientStates, 100);
    }

    function testPredictPriceInvalidData() public {
        StateAggregation.ChainState[] memory invalidStates = new StateAggregation.ChainState[](15);
        
        for (uint256 i = 0; i < 15; i++) {
            invalidStates[i] = StateAggregation.ChainState({
                chainId: 1,
                liquidity: 1000000e18,
                price: 0, // Invalid price
                volume24h: 50000e18,
                lastUpdateBlock: 1000 + i * 10,
                confidence: 90e16,
                isValid: false // Invalid state
            });
        }
        
        vm.expectRevert("Insufficient valid data");
        wrapper.predictPrice(invalidStates, 100);
    }

    function testPredictPriceHorizonTooFar() public {
        uint256 timeHorizon = PredictiveAnalytics.MAX_PREDICTION_HORIZON + 1;
        
        vm.expectRevert("Horizon too far");
        wrapper.predictPrice(historicalStates, timeHorizon);
    }

    function testPredictLiquidityCapsAt2x() public {
        // Create states with very high growth rate
        StateAggregation.ChainState[] memory highGrowthStates = new StateAggregation.ChainState[](15);
        
        for (uint256 i = 0; i < 15; i++) {
            highGrowthStates[i] = StateAggregation.ChainState({
                chainId: 1,
                liquidity: 1000000e18 + (i * 100000e18), // Very high growth
                price: 2000e18,
                volume24h: 50000e18,
                lastUpdateBlock: 1000 + i * 10,
                confidence: 90e16,
                isValid: true
            });
        }
        
        PredictiveAnalytics.PredictionResult memory result = wrapper.predictLiquidity(
            highGrowthStates,
            1000
        );
        
        // Should be capped at 2x current liquidity
        uint256 currentLiquidity = highGrowthStates[14].liquidity;
        assertTrue(result.predictedValue <= currentLiquidity * 2, "Predicted liquidity should be capped at 2x current");
    }

    function testAnalyzeMarketTrendsNoValidChains() public {
        StateAggregation.ChainState[] memory emptyStates = new StateAggregation.ChainState[](0);
        
        vm.expectRevert("No chain states provided");
        wrapper.analyzeMarketTrends(emptyStates, historicalStates);
    }

    function testPredictOptimalRebalancingTimingInsufficientChains() public {
        StateAggregation.ChainState[] memory singleChain = new StateAggregation.ChainState[](1);
        singleChain[0] = currentStates[0];
        
        vm.expectRevert("Need multiple chains for rebalancing");
        wrapper.predictOptimalRebalancingTiming(singleChain, historicalStates, 500);
    }

    function testPredictOptimalRebalancingTimingHorizonTooFar() public {
        uint256 timeHorizon = PredictiveAnalytics.MAX_PREDICTION_HORIZON + 1;
        
        vm.expectRevert("Horizon too far");
        wrapper.predictOptimalRebalancingTiming(currentStates, historicalStates, timeHorizon);
    }

    function testLinearRegressionCalculation() public {
        uint256[] memory values = new uint256[](5);
        uint256[] memory timestamps = new uint256[](5);
        
        for (uint256 i = 0; i < 5; i++) {
            values[i] = 1000 + i * 100;
            timestamps[i] = 1000 + i * 10;
        }
        
        // This tests the internal _calculateLinearRegression function indirectly
        // through predictPrice which uses it
        PredictiveAnalytics.PredictionResult memory result = wrapper.predictPrice(
            historicalStates,
            100
        );
        
        assertTrue(result.predictedValue > 0, "Linear regression should produce valid results");
    }

    function testVolatilityCalculation() public {
        // Create states with high volatility
        StateAggregation.ChainState[] memory volatileStates = new StateAggregation.ChainState[](15);
        
        for (uint256 i = 0; i < 15; i++) {
            volatileStates[i] = StateAggregation.ChainState({
                chainId: 1,
                liquidity: 1000000e18,
                price: 2000e18 + (i % 2 == 0 ? 100e18 : 50e18), // Alternating high/low prices
                volume24h: 50000e18,
                lastUpdateBlock: 1000 + i * 10,
                confidence: 90e16,
                isValid: true
            });
        }
        
        PredictiveAnalytics.PredictionResult memory result = wrapper.predictPrice(
            volatileStates,
            100
        );
        
        assertTrue(result.volatility > 0, "Volatility should be calculated for volatile data");
        console.log("Volatility for volatile data:", result.volatility);
    }

    function testConfidenceCalculation() public {
        // Test with different data quality scenarios
        StateAggregation.ChainState[] memory lowQualityStates = new StateAggregation.ChainState[](15);
        
        for (uint256 i = 0; i < 15; i++) {
            lowQualityStates[i] = StateAggregation.ChainState({
                chainId: 1,
                liquidity: 1000000e18,
                price: 2000e18 + (i * 5e18), // Small price changes
                volume24h: 50000e18,
                lastUpdateBlock: 1000 + i * 10,
                confidence: 50e16, // Lower confidence
                isValid: true
            });
        }
        
        PredictiveAnalytics.PredictionResult memory result = wrapper.predictPrice(
            lowQualityStates,
            1000 // Long horizon
        );
        
        assertTrue(result.confidence >= PredictiveAnalytics.MIN_PREDICTION_CONFIDENCE, "Confidence should meet minimum");
        assertTrue(result.confidence < 1e18, "Confidence should be less than 100% for low quality data");
    }

    function testTrendDirectionCalculation() public {
        // Test upward trend
        StateAggregation.ChainState[] memory upwardTrend = new StateAggregation.ChainState[](15);
        
        for (uint256 i = 0; i < 15; i++) {
            upwardTrend[i] = StateAggregation.ChainState({
                chainId: 1,
                liquidity: 1000000e18,
                price: 2000e18 + (i * 10e18), // Moderate upward trend
                volume24h: 50000e18,
                lastUpdateBlock: 1000 + i * 10,
                confidence: 90e16,
                isValid: true
            });
        }
        
        PredictiveAnalytics.PredictionResult memory result = wrapper.predictPrice(
            upwardTrend,
            100
        );
        
        assertEq(result.trendDirection, 1, "Should detect upward trend");
        
        // Test stable trend (no change)
        StateAggregation.ChainState[] memory stableTrend = new StateAggregation.ChainState[](15);
        
        for (uint256 i = 0; i < 15; i++) {
            stableTrend[i] = StateAggregation.ChainState({
                chainId: 1,
                liquidity: 1000000e18,
                price: 2000e18, // Same price throughout
                volume24h: 50000e18,
                lastUpdateBlock: 1000 + i * 10,
                confidence: 90e16,
                isValid: true
            });
        }
        
        result = wrapper.predictPrice(stableTrend, 100);
        assertEq(result.trendDirection, 0, "Should detect stable trend");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {StateAggregation} from "../../src/avs/libraries/StateAggregation.sol";

// Wrapper contract to test internal functions
contract StateAggregationWrapper {
    using StateAggregation for StateAggregation.ChainState;
    
    function aggregateStates(
        StateAggregation.ChainState[] memory chainStates,
        uint256 currentBlock
    ) external pure returns (StateAggregation.AggregatedState memory) {
        return StateAggregation.aggregateStates(chainStates, currentBlock);
    }
    
    function calculateRebalancingRecommendations(
        StateAggregation.ChainState[] memory chainStates,
        StateAggregation.AggregatedState memory aggregatedState
    ) external pure returns (uint256[] memory rebalancingChains, int256[] memory rebalancingAmounts) {
        return StateAggregation.calculateRebalancingRecommendations(chainStates, aggregatedState);
    }
    
    function calculateConfidenceScore(
        StateAggregation.ChainState memory state,
        uint256 currentBlock,
        StateAggregation.ChainState[] memory historicalStates
    ) external pure returns (uint256 confidence) {
        return StateAggregation.calculateConfidenceScore(state, currentBlock, historicalStates);
    }
    
    function detectAnomalies(
        StateAggregation.ChainState[] memory chainStates,
        StateAggregation.AggregatedState memory aggregatedState
    ) external pure returns (uint256[] memory anomalyChains, uint256[] memory anomalyTypes) {
        return StateAggregation.detectAnomalies(chainStates, aggregatedState);
    }
}

contract StateAggregationTest is Test {
    using StateAggregation for StateAggregation.ChainState;
    using StateAggregation for StateAggregation.AggregatedState;
    
    StateAggregationWrapper wrapper;

    StateAggregation.ChainState[] private chainStates;
    uint256 private currentBlock = 2000;

    function setUp() public {
        wrapper = new StateAggregationWrapper();
        
        // Create test chain states
        chainStates = new StateAggregation.ChainState[](4);
        
        chainStates[0] = StateAggregation.ChainState({
            chainId: 1,
            liquidity: 1000000e18,
            price: 2000e18,
            volume24h: 50000e18,
            lastUpdateBlock: 1950,
            confidence: 90e16,
            isValid: true
        });
        
        chainStates[1] = StateAggregation.ChainState({
            chainId: 42161,
            liquidity: 1200000e18,
            price: 2050e18,
            volume24h: 60000e18,
            lastUpdateBlock: 1980,
            confidence: 85e16,
            isValid: true
        });
        
        chainStates[2] = StateAggregation.ChainState({
            chainId: 137,
            liquidity: 800000e18,
            price: 1950e18,
            volume24h: 40000e18,
            lastUpdateBlock: 1990,
            confidence: 88e16,
            isValid: true
        });
        
        chainStates[3] = StateAggregation.ChainState({
            chainId: 10,
            liquidity: 1100000e18,
            price: 2020e18,
            volume24h: 55000e18,
            lastUpdateBlock: 1995,
            confidence: 92e16,
            isValid: true
        });
    }

    function testAggregateStates() public {
        StateAggregation.AggregatedState memory result = wrapper.aggregateStates(
            chainStates,
            currentBlock
        );
        
        assertTrue(result.totalLiquidity > 0, "Total liquidity should be positive");
        assertTrue(result.averagePrice > 0, "Average price should be positive");
        assertTrue(result.totalVolume24h > 0, "Total volume should be positive");
        assertTrue(result.confidenceScore > 0, "Confidence score should be positive");
        assertEq(result.activeChains, 4, "Should have 4 active chains");
        assertEq(result.lastUpdateBlock, currentBlock, "Last update block should match current block");
        
        console.log("Total liquidity:", result.totalLiquidity);
        console.log("Average price:", result.averagePrice);
        console.log("Price variance:", result.priceVariance);
        console.log("Imbalance score:", result.imbalanceScore);
        console.log("Total volume 24h:", result.totalVolume24h);
        console.log("Confidence score:", result.confidenceScore);
        console.log("Active chains:", result.activeChains);
    }

    function testAggregateStatesEmptyArray() public {
        StateAggregation.ChainState[] memory emptyStates = new StateAggregation.ChainState[](0);
        
        vm.expectRevert("No chain states provided");
        wrapper.aggregateStates(emptyStates, currentBlock);
    }

    function testAggregateStatesTooManyChains() public {
        StateAggregation.ChainState[] memory tooManyStates = new StateAggregation.ChainState[](21);
        
        for (uint256 i = 0; i < 21; i++) {
            tooManyStates[i] = StateAggregation.ChainState({
                chainId: i + 1,
                liquidity: 1000000e18,
                price: 2000e18,
                volume24h: 50000e18,
                lastUpdateBlock: currentBlock - 10,
                confidence: 90e16,
                isValid: true
            });
        }
        
        vm.expectRevert("Too many chains");
        wrapper.aggregateStates(tooManyStates, currentBlock);
    }

    function testAggregateStatesNoValidChains() public {
        StateAggregation.ChainState[] memory invalidStates = new StateAggregation.ChainState[](2);
        
        invalidStates[0] = StateAggregation.ChainState({
            chainId: 1,
            liquidity: 1000000e18,
            price: 2000e18,
            volume24h: 50000e18,
            lastUpdateBlock: currentBlock - 400, // Too old
            confidence: 90e16,
            isValid: false
        });
        
        invalidStates[1] = StateAggregation.ChainState({
            chainId: 2,
            liquidity: 1000000e18,
            price: 2000e18,
            volume24h: 50000e18,
            lastUpdateBlock: currentBlock - 10,
            confidence: 70e16, // Too low confidence
            isValid: true
        });
        
        vm.expectRevert("No valid chain states");
        wrapper.aggregateStates(invalidStates, currentBlock);
    }

    function testCalculateRebalancingRecommendations() public {
        StateAggregation.AggregatedState memory aggregatedState = wrapper.aggregateStates(
            chainStates,
            currentBlock
        );
        
        (uint256[] memory rebalancingChains, int256[] memory rebalancingAmounts) = 
            wrapper.calculateRebalancingRecommendations(chainStates, aggregatedState);
        
        assertTrue(rebalancingChains.length <= chainStates.length, "Should not exceed number of chains");
        assertEq(rebalancingChains.length, rebalancingAmounts.length, "Arrays should have same length");
        
        for (uint256 i = 0; i < rebalancingChains.length; i++) {
            assertTrue(rebalancingChains[i] > 0, "Chain ID should be positive");
            assertTrue(rebalancingAmounts[i] != 0, "Rebalancing amount should not be zero");
        }
        
        console.log("Rebalancing chains count:", rebalancingChains.length);
        for (uint256 i = 0; i < rebalancingChains.length; i++) {
            console.log("Chain", rebalancingChains[i]);
            console.log("Amount", rebalancingAmounts[i]);
        }
    }

    function testCalculateRebalancingRecommendationsInsufficientChains() public {
        StateAggregation.ChainState[] memory singleChain = new StateAggregation.ChainState[](1);
        singleChain[0] = chainStates[0];
        
        StateAggregation.AggregatedState memory aggregatedState = wrapper.aggregateStates(
            singleChain,
            currentBlock
        );
        
        vm.expectRevert("Need at least 2 valid chains for rebalancing");
        wrapper.calculateRebalancingRecommendations(singleChain, aggregatedState);
    }

    function testCalculateConfidenceScore() public {
        StateAggregation.ChainState memory state = chainStates[0];
        StateAggregation.ChainState[] memory historicalStates = new StateAggregation.ChainState[](3);
        
        // Create historical states
        for (uint256 i = 0; i < 3; i++) {
            historicalStates[i] = StateAggregation.ChainState({
                chainId: 1,
                liquidity: 1000000e18 + (i * 10000e18),
                price: 2000e18 + (i * 10e18),
                volume24h: 50000e18,
                lastUpdateBlock: currentBlock - 50 - (i * 10),
                confidence: 90e16,
                isValid: true
            });
        }
        
        uint256 confidence = wrapper.calculateConfidenceScore(
            state,
            currentBlock,
            historicalStates
        );
        
        assertTrue(confidence >= 10e16, "Confidence should be at least 10%");
        assertTrue(confidence <= 100e16, "Confidence should be at most 100%");
        
        console.log("Calculated confidence:", confidence);
    }

    function testCalculateConfidenceScoreOldState() public {
        StateAggregation.ChainState memory oldState = StateAggregation.ChainState({
            chainId: 1,
            liquidity: 1000000e18,
            price: 2000e18,
            volume24h: 50000e18,
            lastUpdateBlock: currentBlock - 400, // Very old
            confidence: 90e16,
            isValid: true
        });
        
        uint256 confidence = wrapper.calculateConfidenceScore(
            oldState,
            currentBlock,
            new StateAggregation.ChainState[](0)
        );
        
        assertEq(confidence, 0, "Old state should have 0 confidence");
    }

    function testDetectAnomalies() public {
        StateAggregation.AggregatedState memory aggregatedState = wrapper.aggregateStates(
            chainStates,
            currentBlock
        );
        
        (uint256[] memory anomalyChains, uint256[] memory anomalyTypes) = 
            wrapper.detectAnomalies(chainStates, aggregatedState);
        
        assertEq(anomalyChains.length, anomalyTypes.length, "Arrays should have same length");
        
        for (uint256 i = 0; i < anomalyChains.length; i++) {
            assertTrue(anomalyChains[i] > 0, "Chain ID should be positive");
            assertTrue(anomalyTypes[i] > 0, "Anomaly type should be positive");
        }
        
        console.log("Anomalies detected:", anomalyChains.length);
        for (uint256 i = 0; i < anomalyChains.length; i++) {
            console.log("Chain", anomalyChains[i]);
            console.log("Anomaly type", anomalyTypes[i]);
        }
    }

    function testDetectAnomaliesEmptyArray() public {
        StateAggregation.ChainState[] memory emptyStates = new StateAggregation.ChainState[](0);
        StateAggregation.AggregatedState memory aggregatedState = StateAggregation.AggregatedState({
            totalLiquidity: 1000000e18,
            averagePrice: 2000e18,
            priceVariance: 0,
            imbalanceScore: 0,
            totalVolume24h: 50000e18,
            confidenceScore: 90e16,
            lastUpdateBlock: currentBlock,
            activeChains: 0
        });
        
        vm.expectRevert("No chain states provided");
        wrapper.detectAnomalies(emptyStates, aggregatedState);
    }

    function testDetectPriceAnomaly() public {
        // Create states with price anomaly
        StateAggregation.ChainState[] memory anomalousStates = new StateAggregation.ChainState[](2);
        
        anomalousStates[0] = StateAggregation.ChainState({
            chainId: 1,
            liquidity: 1000000e18,
            price: 2000e18,
            volume24h: 50000e18,
            lastUpdateBlock: currentBlock - 10,
            confidence: 90e16,
            isValid: true
        });
        
        anomalousStates[1] = StateAggregation.ChainState({
            chainId: 2,
            liquidity: 1000000e18,
            price: 3000e18, // 50% higher than average (anomaly)
            volume24h: 50000e18,
            lastUpdateBlock: currentBlock - 10,
            confidence: 90e16,
            isValid: true
        });
        
        StateAggregation.AggregatedState memory aggregatedState = wrapper.aggregateStates(
            anomalousStates,
            currentBlock
        );
        
        (uint256[] memory anomalyChains, uint256[] memory anomalyTypes) = 
            wrapper.detectAnomalies(anomalousStates, aggregatedState);
        
        assertTrue(anomalyChains.length > 0, "Should detect price anomaly");
        
        bool foundPriceAnomaly = false;
        for (uint256 i = 0; i < anomalyTypes.length; i++) {
            if (anomalyTypes[i] & 1 == 1) { // Check for price anomaly bit
                foundPriceAnomaly = true;
                break;
            }
        }
        assertTrue(foundPriceAnomaly, "Should detect price anomaly");
    }

    function testDetectLiquidityAnomaly() public {
        // Create states with liquidity anomaly
        StateAggregation.ChainState[] memory anomalousStates = new StateAggregation.ChainState[](2);
        
        anomalousStates[0] = StateAggregation.ChainState({
            chainId: 1,
            liquidity: 1000000e18,
            price: 2000e18,
            volume24h: 50000e18,
            lastUpdateBlock: currentBlock - 10,
            confidence: 90e16,
            isValid: true
        });
        
        anomalousStates[1] = StateAggregation.ChainState({
            chainId: 2,
            liquidity: 200000e18, // Much less than expected (anomaly)
            price: 2000e18,
            volume24h: 50000e18,
            lastUpdateBlock: currentBlock - 10,
            confidence: 90e16,
            isValid: true
        });
        
        StateAggregation.AggregatedState memory aggregatedState = wrapper.aggregateStates(
            anomalousStates,
            currentBlock
        );
        
        (uint256[] memory anomalyChains, uint256[] memory anomalyTypes) = 
            wrapper.detectAnomalies(anomalousStates, aggregatedState);
        
        assertTrue(anomalyChains.length > 0, "Should detect liquidity anomaly");
        
        bool foundLiquidityAnomaly = false;
        for (uint256 i = 0; i < anomalyTypes.length; i++) {
            if (anomalyTypes[i] & 2 == 2) { // Check for liquidity anomaly bit
                foundLiquidityAnomaly = true;
                break;
            }
        }
        assertTrue(foundLiquidityAnomaly, "Should detect liquidity anomaly");
    }


    function testDetectConfidenceAnomaly() public {
        // Create states with confidence anomaly
        StateAggregation.ChainState[] memory anomalousStates = new StateAggregation.ChainState[](2);
        
        anomalousStates[0] = StateAggregation.ChainState({
            chainId: 1,
            liquidity: 1000000e18,
            price: 2000e18,
            volume24h: 50000e18,
            lastUpdateBlock: currentBlock - 10,
            confidence: 90e16,
            isValid: true
        });
        
        anomalousStates[1] = StateAggregation.ChainState({
            chainId: 2,
            liquidity: 1000000e18,
            price: 2000e18,
            volume24h: 50000e18,
            lastUpdateBlock: currentBlock - 10,
            confidence: 20e16, // Very low confidence (anomaly)
            isValid: true
        });
        
        StateAggregation.AggregatedState memory aggregatedState = wrapper.aggregateStates(
            anomalousStates,
            currentBlock
        );
        
        (uint256[] memory anomalyChains, uint256[] memory anomalyTypes) = 
            wrapper.detectAnomalies(anomalousStates, aggregatedState);
        
        assertTrue(anomalyChains.length > 0, "Should detect confidence anomaly");
        
        bool foundConfidenceAnomaly = false;
        for (uint256 i = 0; i < anomalyTypes.length; i++) {
            if (anomalyTypes[i] & 8 == 8) { // Check for confidence anomaly bit
                foundConfidenceAnomaly = true;
                break;
            }
        }
        assertTrue(foundConfidenceAnomaly, "Should detect confidence anomaly");
    }

    function testAbsFunction() public {
        // Test internal _abs function through aggregateStates
        StateAggregation.ChainState[] memory testStates = new StateAggregation.ChainState[](2);
        
        testStates[0] = StateAggregation.ChainState({
            chainId: 1,
            liquidity: 1000000e18,
            price: 2000e18,
            volume24h: 50000e18,
            lastUpdateBlock: currentBlock - 10,
            confidence: 90e16,
            isValid: true
        });
        
        testStates[1] = StateAggregation.ChainState({
            chainId: 2,
            liquidity: 1200000e18,
            price: 2200e18,
            volume24h: 60000e18,
            lastUpdateBlock: currentBlock - 10,
            confidence: 90e16,
            isValid: true
        });
        
        StateAggregation.AggregatedState memory result = StateAggregation.aggregateStates(
            testStates,
            currentBlock
        );
        
        assertTrue(result.priceVariance > 0, "Price variance should be calculated");
        assertTrue(result.imbalanceScore > 0, "Imbalance score should be calculated");
    }

    function testVolatilityCalculation() public {
        StateAggregation.ChainState memory currentState = chainStates[0];
        StateAggregation.ChainState[] memory historicalStates = new StateAggregation.ChainState[](5);
        
        // Create historical states with varying prices
        for (uint256 i = 0; i < 5; i++) {
            historicalStates[i] = StateAggregation.ChainState({
                chainId: 1,
                liquidity: 1000000e18,
                price: 2000e18 + (i * 50e18), // Increasing prices
                volume24h: 50000e18,
                lastUpdateBlock: currentBlock - 100 - (i * 10),
                confidence: 90e16,
                isValid: true
            });
        }
        
        uint256 confidence = StateAggregation.calculateConfidenceScore(
            currentState,
            currentBlock,
            historicalStates
        );
        
        assertTrue(confidence > 0, "Confidence should be calculated");
        assertTrue(confidence < 100e16, "Confidence should be less than 100% due to volatility");
    }
}

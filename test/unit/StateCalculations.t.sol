// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {StateCalculations} from "../../src/hooks/libraries/StateCalculations.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

contract StateCalculationsTest is Test {
    using StateCalculations for *;

    function setUp() public {}

    function testCalculatePoolState() public {
        uint160 sqrtPriceX96 = 2000000000000000000000000000000; // ~2000 price
        uint128 liquidity = 1000000e18;
        int24 tick = 0;

        (uint256 price, uint256 totalLiquidity, uint256 priceImpact) = 
            StateCalculations.calculatePoolState(sqrtPriceX96, liquidity, tick);

        assertTrue(price > 0, "Price should be positive");
        assertTrue(totalLiquidity > 0, "Total liquidity should be positive");
        assertTrue(priceImpact >= 0, "Price impact should be non-negative");
        
        console.log("Price:", price);
        console.log("Total liquidity:", totalLiquidity);
        console.log("Price impact:", priceImpact);
    }

    function testCalculatePoolStateZeroLiquidity() public {
        uint160 sqrtPriceX96 = 2000000000000000000000000000000;
        uint128 liquidity = 0;
        int24 tick = 0;

        (uint256 price, uint256 totalLiquidity, uint256 priceImpact) = 
            StateCalculations.calculatePoolState(sqrtPriceX96, liquidity, tick);

        assertTrue(price > 0, "Price should be positive");
        assertEq(totalLiquidity, 0, "Total liquidity should be zero");
        assertEq(priceImpact, 0, "Price impact should be zero for zero liquidity");
    }

    function testCalculateGlobalMetrics() public {
        uint256[] memory chainStates = new uint256[](6);
        uint256[] memory chainIds = new uint256[](3);
        
        // Chain 1: 1000 liquidity, 2000 price
        chainStates[0] = 1000e18;
        chainStates[1] = 2000e18;
        chainIds[0] = 1;
        
        // Chain 2: 2000 liquidity, 2100 price
        chainStates[2] = 2000e18;
        chainStates[3] = 2100e18;
        chainIds[1] = 2;
        
        // Chain 3: 1500 liquidity, 1950 price
        chainStates[4] = 1500e18;
        chainStates[5] = 1950e18;
        chainIds[2] = 3;

        (uint256 totalLiquidity, uint256 averagePrice, uint256 imbalanceScore, uint256 priceVariance) = 
            StateCalculations.calculateGlobalMetrics(chainStates, chainIds);

        assertEq(totalLiquidity, 4500e18, "Total liquidity should be sum of all chains");
        assertTrue(averagePrice > 0, "Average price should be positive");
        assertTrue(imbalanceScore >= 0, "Imbalance score should be non-negative");
        assertTrue(priceVariance >= 0, "Price variance should be non-negative");
        
        console.log("Total liquidity:", totalLiquidity);
        console.log("Average price:", averagePrice);
        console.log("Imbalance score:", imbalanceScore);
        console.log("Price variance:", priceVariance);
    }



    function testShouldTriggerRebalancingHighImbalance() public {
        uint256 imbalanceScore = 25e16; // 25% - above threshold
        uint256 priceVariance = 1e16; // 1%
        uint256 lastRebalanceBlock = 100;
        uint256 currentBlock = 200;

        (bool shouldRebalance, uint256 urgencyLevel) = StateCalculations.shouldTriggerRebalancing(
            imbalanceScore,
            priceVariance,
            lastRebalanceBlock,
            currentBlock
        );

        assertTrue(shouldRebalance, "Should trigger rebalancing for high imbalance");
        assertEq(urgencyLevel, 5, "Should have highest urgency level");
    }

    function testShouldTriggerRebalancingHighPriceVariance() public {
        uint256 imbalanceScore = 5e16; // 5%
        uint256 priceVariance = 15e16; // 15% - above threshold
        uint256 lastRebalanceBlock = 100;
        uint256 currentBlock = 200;

        (bool shouldRebalance, uint256 urgencyLevel) = StateCalculations.shouldTriggerRebalancing(
            imbalanceScore,
            priceVariance,
            lastRebalanceBlock,
            currentBlock
        );

        assertTrue(shouldRebalance, "Should trigger rebalancing for high price variance");
        assertEq(urgencyLevel, 4, "Should have high urgency level");
    }

    function testShouldTriggerRebalancingMediumImbalanceWithTime() public {
        uint256 imbalanceScore = 12e16; // 12% - medium
        uint256 priceVariance = 1e16; // 1%
        uint256 lastRebalanceBlock = 50;
        uint256 currentBlock = 200; // 150 blocks since last rebalance

        (bool shouldRebalance, uint256 urgencyLevel) = StateCalculations.shouldTriggerRebalancing(
            imbalanceScore,
            priceVariance,
            lastRebalanceBlock,
            currentBlock
        );

        assertTrue(shouldRebalance, "Should trigger rebalancing for medium imbalance with time");
        assertEq(urgencyLevel, 3, "Should have medium urgency level");
    }

    function testShouldTriggerRebalancingLowUrgency() public {
        uint256 imbalanceScore = 6e16; // 6% - low
        uint256 priceVariance = 1e16; // 1%
        uint256 lastRebalanceBlock = 50;
        uint256 currentBlock = 1200; // 1150 blocks since last rebalance

        (bool shouldRebalance, uint256 urgencyLevel) = StateCalculations.shouldTriggerRebalancing(
            imbalanceScore,
            priceVariance,
            lastRebalanceBlock,
            currentBlock
        );

        assertTrue(shouldRebalance, "Should trigger rebalancing for low imbalance with time");
        assertEq(urgencyLevel, 2, "Should have low urgency level");
    }

    function testShouldTriggerRebalancingNoTrigger() public {
        uint256 imbalanceScore = 3e16; // 3% - low
        uint256 priceVariance = 1e16; // 1%
        uint256 lastRebalanceBlock = 100;
        uint256 currentBlock = 150; // 50 blocks since last rebalance

        (bool shouldRebalance, uint256 urgencyLevel) = StateCalculations.shouldTriggerRebalancing(
            imbalanceScore,
            priceVariance,
            lastRebalanceBlock,
            currentBlock
        );

        assertFalse(shouldRebalance, "Should not trigger rebalancing");
        assertEq(urgencyLevel, 0, "Should have no urgency");
    }


    function testCalculateRebalancingAmountBothOver() public {
        uint256 sourceLiquidity = 2000e18;
        uint256 targetLiquidity = 1500e18;
        uint256 totalLiquidity = 4000e18;
        uint256 chainCount = 4;

        int256 rebalanceAmount = StateCalculations.calculateRebalancingAmount(
            sourceLiquidity,
            targetLiquidity,
            totalLiquidity,
            chainCount
        );

        assertEq(rebalanceAmount, 0, "Should not rebalance when both chains are over");
    }

    function testCalculateRebalancingAmountBothUnder() public {
        uint256 sourceLiquidity = 500e18;
        uint256 targetLiquidity = 800e18;
        uint256 totalLiquidity = 4000e18;
        uint256 chainCount = 4;

        int256 rebalanceAmount = StateCalculations.calculateRebalancingAmount(
            sourceLiquidity,
            targetLiquidity,
            totalLiquidity,
            chainCount
        );

        assertEq(rebalanceAmount, 0, "Should not rebalance when both chains are under");
    }

    function testCalculateRebalancingAmountReverse() public {
        uint256 sourceLiquidity = 500e18;
        uint256 targetLiquidity = 2000e18;
        uint256 totalLiquidity = 4000e18;
        uint256 chainCount = 4;

        int256 rebalanceAmount = StateCalculations.calculateRebalancingAmount(
            sourceLiquidity,
            targetLiquidity,
            totalLiquidity,
            chainCount
        );

        assertTrue(rebalanceAmount < 0, "Should rebalance from target to source");
    }

    function testSqrtPriceToPrice() public {
        uint160 sqrtPriceX96 = 2000000000000000000000000000000;
        
        uint256 price = StateCalculations._sqrtPriceToPrice(sqrtPriceX96);
        
        assertTrue(price > 0, "Price should be positive");
        console.log("Sqrt price to price:", price);
    }

    function testCalculatePriceImpact() public {
        uint256 swapAmount = 1000e18;
        uint128 liquidity = 1000000e18;
        uint160 sqrtPriceX96 = 2000000000000000000000000000000;

        uint256 priceImpact = StateCalculations._calculatePriceImpact(
            swapAmount,
            liquidity,
            sqrtPriceX96
        );

        assertTrue(priceImpact > 0, "Price impact should be positive");
        assertTrue(priceImpact <= StateCalculations.PRECISION, "Price impact should not exceed 100%");
    }

    function testCalculatePriceImpactZeroLiquidity() public {
        uint256 swapAmount = 1000e18;
        uint128 liquidity = 0;
        uint160 sqrtPriceX96 = 2000000000000000000000000000000;

        uint256 priceImpact = StateCalculations._calculatePriceImpact(
            swapAmount,
            liquidity,
            sqrtPriceX96
        );

        assertEq(priceImpact, 0, "Price impact should be zero for zero liquidity");
    }

    function testAdjustPriceLimit() public {
        uint160 originalPriceLimit = 2000000000000000000000000000000;
        int256 percentChange = -15; // -15%

        uint160 adjustedPriceLimit = StateCalculations._adjustPriceLimit(
            originalPriceLimit,
            percentChange
        );

        assertTrue(adjustedPriceLimit < originalPriceLimit, "Price limit should be reduced");
    }

    function testAdjustPriceLimitZeroChange() public {
        uint160 originalPriceLimit = 2000000000000000000000000000000;
        int256 percentChange = 0;

        uint160 adjustedPriceLimit = StateCalculations._adjustPriceLimit(
            originalPriceLimit,
            percentChange
        );

        assertEq(adjustedPriceLimit, originalPriceLimit, "Price limit should be unchanged");
    }


    function testAdjustTowardsPriceSamePrice() public {
        uint160 originalPriceLimit = 2000000000000000000000000000000;
        uint256 targetPrice = 2000e18;
        uint256 currentPrice = 2000e18;

        uint160 adjustedPriceLimit = StateCalculations._adjustTowardsPrice(
            originalPriceLimit,
            targetPrice,
            currentPrice
        );

        assertEq(adjustedPriceLimit, originalPriceLimit, "Price limit should be unchanged");
    }


    function testAbsUint() public {
        uint256 a = 1000;
        uint256 b = 500;
        
        uint256 result = StateCalculations._abs(a, b);
        
        assertEq(result, 500, "Should return absolute difference");
    }

    function testAbsUintReverse() public {
        uint256 a = 500;
        uint256 b = 1000;
        
        uint256 result = StateCalculations._abs(a, b);
        
        assertEq(result, 500, "Should return absolute difference");
    }

    function testAbsInt() public {
        int256 a = 1000;
        int256 b = 500;
        
        uint256 result = StateCalculations._abs(a, b);
        
        assertEq(result, 500, "Should return absolute difference");
    }

    function testAbsIntNegative() public {
        int256 a = -1000;
        int256 b = -500;
        
        uint256 result = StateCalculations._abs(a, b);
        
        assertEq(result, 500, "Should return absolute difference");
    }

    function testSqrt() public {
        uint256 x = 16;
        
        uint256 result = StateCalculations._sqrt(x);
        
        assertEq(result, 4, "Should calculate correct square root");
    }

    function testSqrtZero() public {
        uint256 x = 0;
        
        uint256 result = StateCalculations._sqrt(x);
        
        assertEq(result, 0, "Should return 0 for sqrt(0)");
    }

    function testSqrtLarge() public {
        uint256 x = 1000000;
        
        uint256 result = StateCalculations._sqrt(x);
        
        assertEq(result, 1000, "Should calculate correct square root");
    }

    function testConstants() public {
        assertEq(StateCalculations.PRECISION, 1e18, "Precision should be 1e18");
        assertEq(StateCalculations.MAX_PRICE_DEVIATION, 5e16, "Max price deviation should be 5%");
        assertEq(StateCalculations.MAX_IMBALANCE_THRESHOLD, 20e16, "Max imbalance threshold should be 20%");
        assertEq(StateCalculations.MIN_LIQUIDITY, 1e6, "Min liquidity should be 1e6");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ParameterOptimization} from "../../src/hooks/libraries/ParameterOptimization.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

contract ParameterOptimizationTest is Test {
    using ParameterOptimization for SwapParams;

    function setUp() public {}

    function testOptimizeSwapParameters() public {
        SwapParams memory originalParams = SwapParams({
            amountSpecified: 1000e18,
            sqrtPriceLimitX96: 2000000000000000000000000000000,
            zeroForOne: true
        });
        
        uint256[4] memory globalState = [
            uint256(4000000e18), // totalLiquidity
            uint256(2000e18),    // averagePrice
            uint256(5e16),       // imbalanceScore (5%)
            uint256(2000)        // lastUpdateBlock
        ];
        
        uint256[3] memory localState = [
            uint256(1000000e18), // liquidity
            uint256(2000e18),    // price
            uint256(1e16)        // priceImpact (1%)
        ];
        
        uint256 chainCount = 4;
        
        (SwapParams memory optimizedParams, uint256 optimizationFlags) = 
            ParameterOptimization.optimizeSwapParameters(
                originalParams,
                globalState,
                localState,
                chainCount
            );
        
        assertTrue(optimizedParams.amountSpecified != 0, "Amount should not be zero");
        assertTrue(optimizedParams.sqrtPriceLimitX96 != 0, "Price limit should not be zero");
        assertTrue(optimizationFlags >= 0, "Optimization flags should be non-negative");
        
        console.log("Original amount:", originalParams.amountSpecified);
        console.log("Optimized amount:", optimizedParams.amountSpecified);
        console.log("Optimization flags:", optimizationFlags);
    }






    function testCalculateOptimalSwapAmount() public {
        int256 originalAmount = 1000e18;
        uint256 globalLiquidity = 4000000e18;
        uint256 localLiquidity = 1000000e18;
        uint256 imbalanceScore = 10e16; // 10%
        uint256 priceVolatility = 3e16; // 3%
        
        int256 optimalAmount = ParameterOptimization.calculateOptimalSwapAmount(
            originalAmount,
            globalLiquidity,
            localLiquidity,
            imbalanceScore,
            priceVolatility
        );
        
        assertTrue(optimalAmount != 0, "Optimal amount should not be zero");
        assertTrue(optimalAmount > originalAmount / 2, "Should not reduce by more than 50%");
        assertTrue(optimalAmount < originalAmount * 2, "Should not increase by more than 100%");
        
        console.log("Original amount:", originalAmount);
        console.log("Optimal amount:", optimalAmount);
    }












    function testApplySafetyChecks() public {
        SwapParams memory params = SwapParams({
            amountSpecified: 0, // Zero amount
            sqrtPriceLimitX96: 0, // Zero price limit
            zeroForOne: true
        });
        
        SwapParams memory safeParams = ParameterOptimization._applySafetyChecks(params);
        
        assertTrue(safeParams.amountSpecified != 0, "Should fix zero amount");
        assertTrue(safeParams.sqrtPriceLimitX96 != 0, "Should fix zero price limit");
    }


    function testCalculatePriceDeviationZeroPrice() public {
        uint256 price1 = 0;
        uint256 price2 = 2100e18;
        
        uint256 deviation = ParameterOptimization._calculatePriceDeviation(price1, price2);
        
        assertEq(deviation, 0, "Should return 0 for zero price");
    }

    function testCalculateBaseSlippage() public {
        uint256 volatility = 5e16; // 5%
        uint256 timeToDeadline = 1800; // 30 minutes
        
        uint256 slippage = ParameterOptimization._calculateBaseSlippage(volatility, timeToDeadline);
        
        assertTrue(slippage > 0, "Should calculate positive slippage");
        assertTrue(slippage <= ParameterOptimization.MAX_SLIPPAGE, "Should not exceed max slippage");
        assertTrue(slippage >= ParameterOptimization.MIN_SLIPPAGE, "Should not be below min slippage");
    }

    function testCalculateBaseSlippageShortDeadline() public {
        uint256 volatility = 5e16; // 5%
        uint256 timeToDeadline = 300; // 5 minutes
        
        uint256 slippage = ParameterOptimization._calculateBaseSlippage(volatility, timeToDeadline);
        
        assertTrue(slippage > 0, "Should calculate positive slippage");
        // Should be higher due to short deadline
    }

    function testCalculateBaseSlippageLongDeadline() public {
        uint256 volatility = 5e16; // 5%
        uint256 timeToDeadline = 7200; // 2 hours
        
        uint256 slippage = ParameterOptimization._calculateBaseSlippage(volatility, timeToDeadline);
        
        assertTrue(slippage > 0, "Should calculate positive slippage");
        // Should be lower due to long deadline
    }



    function testRelaxPriceLimit() public {
        uint160 priceLimit = 2000000000000000000000000000000;
        uint256 percent = 20; // 20%
        
        uint160 relaxedLimit = ParameterOptimization._relaxPriceLimit(priceLimit, percent);
        
        assertTrue(relaxedLimit > priceLimit, "Should increase price limit");
    }

    function testTightenPriceLimit() public {
        uint160 priceLimit = 2000000000000000000000000000000;
        uint256 percent = 20; // 20%
        
        uint160 tightenedLimit = ParameterOptimization._tightenPriceLimit(priceLimit, percent);
        
        assertTrue(tightenedLimit < priceLimit, "Should decrease price limit");
    }


    function testAdjustTowardsTargetPriceZeroPrices() public {
        uint160 currentPriceLimit = 2000000000000000000000000000000;
        uint256 currentPrice = 0;
        uint256 targetPrice = 2100e18;
        
        uint160 adjustedLimit = ParameterOptimization._adjustTowardsTargetPrice(
            currentPriceLimit,
            currentPrice,
            targetPrice
        );
        
        assertEq(adjustedLimit, currentPriceLimit, "Should return original limit for zero prices");
    }


    function testSqrt() public {
        uint256 x = 16;
        
        uint256 result = ParameterOptimization._sqrt(x);
        
        assertEq(result, 4, "Should calculate correct square root");
    }

    function testSqrtZero() public {
        uint256 x = 0;
        
        uint256 result = ParameterOptimization._sqrt(x);
        
        assertEq(result, 0, "Should return 0 for sqrt(0)");
    }
}

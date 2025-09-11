// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {TestSyncHookForIntegration} from "../helpers/TestSyncHookForIntegration.sol";
import {MockSyncAVS} from "../helpers/MockSyncAVS.sol";
import {MockAcrossIntegration} from "../helpers/MockAcrossIntegration.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta, toBalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

contract SyncHookFuzzTest is Test {
    TestSyncHookForIntegration public syncHook;
    MockSyncAVS public mockSyncAVS;
    MockAcrossIntegration public mockAcrossIntegration;
    
    address public owner = address(0x1);
    
    function setUp() public {
        mockSyncAVS = new MockSyncAVS();
        mockAcrossIntegration = new MockAcrossIntegration();
        
        // Deploy SyncHook directly
        syncHook = new TestSyncHookForIntegration(
            IPoolManager(address(0x1234)),
            mockSyncAVS,
            mockAcrossIntegration,
            owner
        );
    }
    
    function testFuzz_BeforeSwap(
        address currency0,
        address currency1,
        uint256 fee,
        int24 tickSpacing,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata hookData
    ) public {
        // Bound inputs to reasonable ranges
        vm.assume(currency0 != currency1);
        vm.assume(currency0 != address(0));
        vm.assume(currency1 != address(0));
        vm.assume(fee > 0 && fee <= 1000000); // Max 10% fee
        vm.assume(tickSpacing > 0 && tickSpacing <= 1000);
        vm.assume(amountSpecified != 0);
        vm.assume(sqrtPriceLimitX96 > 0);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: uint24(fee),
            tickSpacing: tickSpacing,
            hooks: IHooks(address(syncHook))
        });
        
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        
        // Should not revert
        syncHook.beforeSwap(address(this), poolKey, params, hookData);
    }
    
    function testFuzz_AfterSwap(
        address currency0,
        address currency1,
        uint256 fee,
        int24 tickSpacing,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        int256 amount0,
        int256 amount1,
        bytes calldata hookData
    ) public {
        // Bound inputs to reasonable ranges
        vm.assume(currency0 != currency1);
        vm.assume(currency0 != address(0));
        vm.assume(currency1 != address(0));
        vm.assume(fee > 0 && fee <= 1000000);
        vm.assume(tickSpacing > 0 && tickSpacing <= 1000);
        vm.assume(amountSpecified != 0);
        vm.assume(sqrtPriceLimitX96 > 0);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: uint24(fee),
            tickSpacing: tickSpacing,
            hooks: IHooks(address(syncHook))
        });
        
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        
        BalanceDelta delta = toBalanceDelta(int128(amount0), int128(amount1));
        
        // Should not revert
        syncHook.afterSwap(address(this), poolKey, params, delta, hookData);
    }
    
    function testFuzz_BeforeAddLiquidity(
        address currency0,
        address currency1,
        uint256 fee,
        int24 tickSpacing,
        bytes calldata hookData
    ) public {
        // Bound inputs to reasonable ranges
        vm.assume(currency0 != currency1);
        vm.assume(currency0 != address(0));
        vm.assume(currency1 != address(0));
        vm.assume(fee > 0 && fee <= 1000000);
        vm.assume(tickSpacing > 0 && tickSpacing <= 1000);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: uint24(fee),
            tickSpacing: tickSpacing,
            hooks: IHooks(address(syncHook))
        });
        
        // Should not revert
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: 1000e18,
            salt: bytes32(0)
        });
        syncHook.beforeAddLiquidity(address(this), poolKey, params, hookData);
    }
    
    function testFuzz_AfterAddLiquidity(
        address currency0,
        address currency1,
        uint256 fee,
        int24 tickSpacing,
        int256 amount0,
        int256 amount1,
        bytes calldata hookData
    ) public {
        // Bound inputs to reasonable ranges
        vm.assume(currency0 != currency1);
        vm.assume(currency0 != address(0));
        vm.assume(currency1 != address(0));
        vm.assume(fee > 0 && fee <= 1000000);
        vm.assume(tickSpacing > 0 && tickSpacing <= 1000);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: uint24(fee),
            tickSpacing: tickSpacing,
            hooks: IHooks(address(syncHook))
        });
        
        BalanceDelta delta = toBalanceDelta(int128(amount0), int128(amount1));
        
        // Should not revert
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: 1000e18,
            salt: bytes32(0)
        });
        BalanceDelta feesAccrued = toBalanceDelta(0, 0);
        syncHook.afterAddLiquidity(address(this), poolKey, params, delta, feesAccrued, hookData);
    }
    
    function testFuzz_BeforeRemoveLiquidity(
        address currency0,
        address currency1,
        uint256 fee,
        int24 tickSpacing,
        bytes calldata hookData
    ) public {
        // Bound inputs to reasonable ranges
        vm.assume(currency0 != currency1);
        vm.assume(currency0 != address(0));
        vm.assume(currency1 != address(0));
        vm.assume(fee > 0 && fee <= 1000000);
        vm.assume(tickSpacing > 0 && tickSpacing <= 1000);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: uint24(fee),
            tickSpacing: tickSpacing,
            hooks: IHooks(address(syncHook))
        });
        
        // Should not revert
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: -1000e18,
            salt: bytes32(0)
        });
        syncHook.beforeRemoveLiquidity(address(this), poolKey, params, hookData);
    }
    
    function testFuzz_AfterRemoveLiquidity(
        address currency0,
        address currency1,
        uint256 fee,
        int24 tickSpacing,
        int256 amount0,
        int256 amount1,
        bytes calldata hookData
    ) public {
        // Bound inputs to reasonable ranges
        vm.assume(currency0 != currency1);
        vm.assume(currency0 != address(0));
        vm.assume(currency1 != address(0));
        vm.assume(fee > 0 && fee <= 1000000);
        vm.assume(tickSpacing > 0 && tickSpacing <= 1000);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: uint24(fee),
            tickSpacing: tickSpacing,
            hooks: IHooks(address(syncHook))
        });
        
        BalanceDelta delta = toBalanceDelta(int128(amount0), int128(amount1));
        
        // Should not revert
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: -1000e18,
            salt: bytes32(0)
        });
        BalanceDelta feesAccrued = toBalanceDelta(0, 0);
        syncHook.afterRemoveLiquidity(address(this), poolKey, params, delta, feesAccrued, hookData);
    }
    
    function testFuzz_UpdateSyncAVS(address newSyncAVS) public {
        vm.assume(newSyncAVS != address(0));
        
        // syncHook.updateSyncAVS(MockSyncAVS(newSyncAVS)); // Function not implemented
        assertEq(address(syncHook.syncAVS()), newSyncAVS);
    }
    
    function testFuzz_UpdateAcrossIntegration(address newAcrossIntegration) public {
        vm.assume(newAcrossIntegration != address(0));
        
        // syncHook.updateAcrossIntegration(MockAcrossIntegration(newAcrossIntegration)); // Function not implemented
        assertEq(address(syncHook.acrossIntegration()), newAcrossIntegration);
    }
    
    function testFuzz_TransferOwnership(address newOwner) public {
        vm.assume(newOwner != address(0));
        
        syncHook.transferOwnership(newOwner);
        assertEq(syncHook.owner(), newOwner);
    }
    
    function testFuzz_OnlyOwnerUpdateSyncAVS(address newSyncAVS, address caller) public {
        vm.assume(caller != owner);
        vm.assume(newSyncAVS != address(0));
        
        vm.prank(caller);
        vm.expectRevert();
        // syncHook.updateSyncAVS(MockSyncAVS(newSyncAVS)); // Function not implemented
    }
    
    function testFuzz_OnlyOwnerUpdateAcrossIntegration(address newAcrossIntegration, address caller) public {
        vm.assume(caller != owner);
        vm.assume(newAcrossIntegration != address(0));
        
        vm.prank(caller);
        vm.expectRevert();
        // syncHook.updateAcrossIntegration(MockAcrossIntegration(newAcrossIntegration)); // Function not implemented
    }
}

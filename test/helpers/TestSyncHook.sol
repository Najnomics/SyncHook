// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SyncHook} from "../../src/hooks/SyncHook.sol";
import {ISyncAVS} from "../../src/hooks/interfaces/ISyncAVS.sol";
import {IAcrossIntegration} from "../../src/hooks/interfaces/IAcrossIntegration.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {BaseHook} from "@uniswap/v4-periphery/utils/BaseHook.sol";

/**
 * @title TestSyncHook
 * @notice Test wrapper for SyncHook that bypasses onlyPoolManager modifier
 */
contract TestSyncHook is SyncHook {
    constructor(
        IPoolManager _poolManager,
        address _syncAVS,
        address _acrossIntegration,
        address _owner
    ) SyncHook(_poolManager, ISyncAVS(_syncAVS), IAcrossIntegration(_acrossIntegration), _owner) {}
    
    /// @notice Override validateHookAddress to allow testing with any address
    function validateHookAddress(BaseHook _this) internal pure override {
        // Skip validation during testing
    }
    
    // Test wrapper functions that bypass the onlyPoolManager modifier
    function testBeforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4, BeforeSwapDelta, uint24) {
        return _beforeSwap(sender, key, params, hookData);
    }
    
    function testAfterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128) {
        return _afterSwap(sender, key, params, delta, hookData);
    }
    
    function testBeforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        return _beforeAddLiquidity(sender, key, params, hookData);
    }
    
    function testAfterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {
        return _afterAddLiquidity(sender, key, params, delta, feesAccrued, hookData);
    }
    
    function testBeforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        return _beforeRemoveLiquidity(sender, key, params, hookData);
    }
    
    function testAfterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {
        return _afterRemoveLiquidity(sender, key, params, delta, feesAccrued, hookData);
    }
}
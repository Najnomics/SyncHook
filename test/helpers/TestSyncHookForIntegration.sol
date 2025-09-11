// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SyncHook} from "../../src/hooks/SyncHook.sol";
import {ISyncAVS} from "../../src/hooks/interfaces/ISyncAVS.sol";
import {IAcrossIntegration} from "../../src/hooks/interfaces/IAcrossIntegration.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BaseHook} from "@uniswap/v4-periphery/utils/BaseHook.sol";

/**
 * @title TestSyncHookForIntegration
 * @notice Test wrapper for SyncHook that bypasses hook address validation for integration tests
 */
contract TestSyncHookForIntegration is SyncHook {
    constructor(
        IPoolManager _poolManager,
        ISyncAVS _syncAVS,
        IAcrossIntegration _acrossIntegration,
        address _owner
    ) SyncHook(_poolManager, _syncAVS, _acrossIntegration, _owner) {}
    
    /// @notice Override validateHookAddress to allow testing with any address
    function validateHookAddress(BaseHook _this) internal pure override {
        // Skip validation during testing
    }
}

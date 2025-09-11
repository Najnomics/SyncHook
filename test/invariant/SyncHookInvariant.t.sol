// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {TestSyncHookForIntegration} from "../helpers/TestSyncHookForIntegration.sol";
import {MockSyncAVS} from "../helpers/MockSyncAVS.sol";
import {MockAcrossIntegration} from "../helpers/MockAcrossIntegration.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

contract SyncHookInvariantTest is StdInvariant, Test {
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
        
        // Set up invariant testing
        targetContract(address(syncHook));
        
        // Don't call functions that change state in invariant tests
        excludeContract(address(mockSyncAVS));
        excludeContract(address(mockAcrossIntegration));
    }
    
    function invariant_OwnerNeverChanges() public {
        assertEq(syncHook.owner(), owner);
    }
    
    function invariant_SyncAVSNeverChanges() public {
        assertEq(address(syncHook.syncAVS()), address(mockSyncAVS));
    }
    
    function invariant_AcrossIntegrationNeverChanges() public {
        assertEq(address(syncHook.acrossIntegration()), address(mockAcrossIntegration));
    }
    
    function invariant_HookPermissionsNeverChanges() public {
        Hooks.Permissions memory permissions = syncHook.getHookPermissions();
        assertTrue(permissions.beforeAddLiquidity);
        assertTrue(permissions.afterAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertTrue(permissions.afterRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
    }
}

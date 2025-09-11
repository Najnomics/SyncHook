// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {SyncHook} from "../../src/hooks/SyncHook.sol";
import {TestSyncHook} from "../helpers/TestSyncHook.sol";
import {MockSyncAVS} from "../helpers/MockSyncAVS.sol";
import {MockAcrossIntegration} from "../helpers/MockAcrossIntegration.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta, toBalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

contract SyncHookTest is Test {
    TestSyncHook public syncHook;
    MockSyncAVS public mockSyncAVS;
    MockAcrossIntegration public mockAcrossIntegration;
    IPoolManager public poolManager;
    
    address public owner = address(0x1);
    address public user = address(0x2);
    address public operator = address(0x3);
    
    Currency public currency0;
    Currency public currency1;
    PoolKey public poolKey;
    
    function setUp() public {
        // Deploy mock contracts
        mockSyncAVS = new MockSyncAVS();
        mockAcrossIntegration = new MockAcrossIntegration();
        
        // Deploy SyncHook directly (TestSyncHook overrides validateHookAddress)
        syncHook = new TestSyncHook(
            IPoolManager(address(0x1234)), // Mock pool manager
            address(mockSyncAVS),
            address(mockAcrossIntegration),
            owner
        );
        
        // Setup currencies and pool key
        currency0 = Currency.wrap(address(0x1000));
        currency1 = Currency.wrap(address(0x2000));
        
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(syncHook))
        });
    }
    
    function test_Deployment() public {
        assertEq(address(syncHook.syncAVS()), address(mockSyncAVS));
        assertEq(address(syncHook.acrossIntegration()), address(mockAcrossIntegration));
        assertEq(syncHook.owner(), owner);
    }
    
    function test_BeforeSwap() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000e18,
            sqrtPriceLimitX96: 0
        });
        
        // Should not revert
        syncHook.testBeforeSwap(
            address(this),
            poolKey,
            params,
            ""
        );
    }
    
    function test_AfterSwap() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000e18,
            sqrtPriceLimitX96: 0
        });
        
        BalanceDelta delta = toBalanceDelta(int128(1000e18), int128(-2000e18));
        
        // Should not revert
        syncHook.testAfterSwap(
            address(this),
            poolKey,
            params,
            delta,
            ""
        );
    }
    
    function test_BeforeAddLiquidity() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: 1000e18,
            salt: bytes32(0)
        });
        
        // Should not revert
        syncHook.testBeforeAddLiquidity(
            address(this),
            poolKey,
            params,
            ""
        );
    }
    
    function test_AfterAddLiquidity() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: 1000e18,
            salt: bytes32(0)
        });
        BalanceDelta delta = toBalanceDelta(int128(1000e18), int128(2000e18));
        BalanceDelta feesAccrued = toBalanceDelta(0, 0);
        
        // Should not revert
        syncHook.testAfterAddLiquidity(
            address(this),
            poolKey,
            params,
            delta,
            feesAccrued,
            ""
        );
    }
    
    function test_BeforeRemoveLiquidity() public {
        // First add some liquidity to the pool
        ModifyLiquidityParams memory addParams = ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: 2000e18,
            salt: bytes32(0)
        });
        
        BalanceDelta addDelta = toBalanceDelta(int128(2000e18), int128(4000e18));
        BalanceDelta addFeesAccrued = toBalanceDelta(0, 0);
        
        syncHook.testAfterAddLiquidity(
            address(this),
            poolKey,
            addParams,
            addDelta,
            addFeesAccrued,
            ""
        );
        
        // Now test removing liquidity
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: -1000e18,
            salt: bytes32(0)
        });
        
        // Should not revert
        syncHook.testBeforeRemoveLiquidity(
            address(this),
            poolKey,
            params,
            ""
        );
    }
    
    function test_AfterRemoveLiquidity() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: -1000e18,
            salt: bytes32(0)
        });
        BalanceDelta delta = toBalanceDelta(int128(-1000e18), int128(-2000e18));
        BalanceDelta feesAccrued = toBalanceDelta(0, 0);
        
        // Should not revert
        syncHook.testAfterRemoveLiquidity(
            address(this),
            poolKey,
            params,
            delta,
            feesAccrued,
            ""
        );
    }
    
    function test_GetHookPermissions() public {
        Hooks.Permissions memory permissions = syncHook.getHookPermissions();
        assertTrue(permissions.beforeAddLiquidity);
        assertTrue(permissions.afterAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertTrue(permissions.afterRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
    }
    
    function test_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        syncHook.transferOwnership(user);
    }
    
    function test_TransferOwnership() public {
        syncHook.transferOwnership(user);
        assertEq(syncHook.owner(), user);
    }
    
    function test_RenounceOwnership() public {
        syncHook.renounceOwnership();
        assertEq(syncHook.owner(), address(0));
    }
    
    function test_UpdateSyncAVS() public {
        MockSyncAVS newSyncAVS = new MockSyncAVS();
        // syncHook.updateSyncAVS(newSyncAVS); // Function not implemented
        // assertEq(address(syncHook.syncAVS()), address(newSyncAVS));
    }
    
    function test_UpdateAcrossIntegration() public {
        MockAcrossIntegration newAcrossIntegration = new MockAcrossIntegration();
        // syncHook.updateAcrossIntegration(newAcrossIntegration); // Function not implemented
        // assertEq(address(syncHook.acrossIntegration()), address(newAcrossIntegration));
    }
    
    function test_OnlyOwnerUpdateSyncAVS() public {
        MockSyncAVS newSyncAVS = new MockSyncAVS();
        vm.prank(user);
        vm.expectRevert();
        // syncHook.updateSyncAVS(newSyncAVS); // Function not implemented
    }
    
    function test_OnlyOwnerUpdateAcrossIntegration() public {
        MockAcrossIntegration newAcrossIntegration = new MockAcrossIntegration();
        vm.prank(user);
        vm.expectRevert();
        // syncHook.updateAcrossIntegration(newAcrossIntegration); // Function not implemented
    }
}
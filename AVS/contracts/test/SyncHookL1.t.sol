// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";

import {SyncHookL1} from "@project/l1-contracts/SyncHookL1.sol";

contract SyncHookL1Test is Test {
    SyncHookL1 public syncHookL1;
    bytes32 public constant TEST_POOL_ID = keccak256("TEST_POOL");

    function setUp() public {
        // Deploy the SyncHookL1 contract
        syncHookL1 = new SyncHookL1();
    }

    function testInitialVersion() view public {
        assertEq(syncHookL1.getVersion(), "SyncHook L1 v1.0.0");
    }

    function testUpdatePoolState() public {
        uint256 totalLiquidity = 1000000000000000000000; // 1000 tokens
        uint256 averagePrice = 2000000000000000000000; // $2000
        uint256 imbalanceScore = 50000000000000000000; // 50 tokens

        syncHookL1.updatePoolState(TEST_POOL_ID, totalLiquidity, averagePrice, imbalanceScore);
        
        (uint256 liquidity, uint256 price, uint256 score, uint64 lastUpdateBlock, uint64 timestamp, bool isActive) = 
            syncHookL1.getPoolState(TEST_POOL_ID);
        
        assertEq(liquidity, totalLiquidity);
        assertEq(price, averagePrice);
        assertEq(score, imbalanceScore);
        assertTrue(isActive);
        assertTrue(lastUpdateBlock > 0);
        assertTrue(timestamp > 0);
    }

    function testTriggerRebalancing() public {
        // First update pool state
        syncHookL1.updatePoolState(TEST_POOL_ID, 1000000000000000000000, 2000000000000000000000, 0);
        
        // Trigger rebalancing
        uint256 amount = 100000000000000000000; // 100 tokens
        uint32 targetChainId = 42161; // Arbitrum
        
        syncHookL1.triggerRebalancing(TEST_POOL_ID, amount, targetChainId);
        
        // Verify pool is still active
        (,,,,, bool isActive) = syncHookL1.getPoolState(TEST_POOL_ID);
        assertTrue(isActive);
    }

    function testInitiateCrossChainSync() public {
        // First update pool state
        syncHookL1.updatePoolState(TEST_POOL_ID, 1000000000000000000000, 2000000000000000000000, 0);
        
        // Initiate cross-chain sync
        uint32 sourceChainId = 1; // Ethereum
        uint32 targetChainId = 42161; // Arbitrum
        uint256 amount = 50000000000000000000; // 50 tokens
        
        syncHookL1.initiateCrossChainSync(TEST_POOL_ID, sourceChainId, targetChainId, amount);
        
        // Verify pool is still active
        (,,,,, bool isActive) = syncHookL1.getPoolState(TEST_POOL_ID);
        assertTrue(isActive);
    }

    function testOnlyAuthorizedCanUpdatePoolState() public {
        // Deploy as non-owner
        address nonOwner = makeAddr("nonOwner");
        vm.prank(nonOwner);
        
        vm.expectRevert("SyncHookL1: caller is not authorized");
        syncHookL1.updatePoolState(TEST_POOL_ID, 1000, 2000, 0);
    }

    function testOwnerCanAddAuthorizedOperator() public {
        address operator = makeAddr("operator");
        
        syncHookL1.addAuthorizedOperator(operator);
        assertTrue(syncHookL1.authorizedOperators(operator));
    }

    function testOwnerCanRemoveAuthorizedOperator() public {
        address operator = makeAddr("operator");
        
        // Add operator
        syncHookL1.addAuthorizedOperator(operator);
        assertTrue(syncHookL1.authorizedOperators(operator));
        
        // Remove operator
        syncHookL1.removeAuthorizedOperator(operator);
        assertFalse(syncHookL1.authorizedOperators(operator));
    }
}

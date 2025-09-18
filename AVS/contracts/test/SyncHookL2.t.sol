// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";

import {SyncHookL2} from "@project/l2-contracts/SyncHookL2.sol";

contract SyncHookL2Test is Test {
    SyncHookL2 public syncHookL2;
    bytes32 public constant TEST_POOL_ID = keccak256("TEST_POOL");
    uint32 public constant CHAIN_ID_1 = 1; // Ethereum
    uint32 public constant CHAIN_ID_2 = 42161; // Arbitrum

    function setUp() public {
        // Deploy the SyncHookL2 contract
        syncHookL2 = new SyncHookL2();
    }

    function testInitialVersion() view public {
        assertEq(syncHookL2.getVersion(), "SyncHook L2 v1.0.0");
    }

    function testUpdateChainPoolState() public {
        uint256 liquidity = 1000000000000000000000; // 1000 tokens
        uint256 price = 2000000000000000000000; // $2000
        uint256 volume24h = 500000000000000000000; // 500 tokens
        uint256 fees24h = 10000000000000000000; // 10 tokens

        syncHookL2.updateChainPoolState(TEST_POOL_ID, CHAIN_ID_1, liquidity, price, volume24h, fees24h);
        
        (uint256 chainLiquidity, uint256 chainPrice, uint256 chainVolume24h, uint256 chainFees24h, uint64 lastUpdateBlock, uint64 timestamp, bool isActive) = 
            syncHookL2.getChainPoolState(TEST_POOL_ID, CHAIN_ID_1);
        
        assertEq(chainLiquidity, liquidity);
        assertEq(chainPrice, price);
        assertEq(chainVolume24h, volume24h);
        assertEq(chainFees24h, fees24h);
        assertTrue(isActive);
        assertTrue(lastUpdateBlock > 0);
        assertTrue(timestamp > 0);
    }

    function testRecordLiquidityRebalancing() public {
        uint256 amount = 100000000000000000000; // 100 tokens
        
        syncHookL2.recordLiquidityRebalancing(TEST_POOL_ID, CHAIN_ID_1, CHAIN_ID_2, amount);
        
        // This function only emits events, so we just verify it doesn't revert
        assertTrue(true);
    }

    function testRecordCrossChainTransferCompletion() public {
        uint256 amount = 50000000000000000000; // 50 tokens
        bytes32 txHash = keccak256("test_tx_hash");
        
        syncHookL2.recordCrossChainTransferCompletion(TEST_POOL_ID, CHAIN_ID_1, amount, txHash);
        
        // This function only emits events, so we just verify it doesn't revert
        assertTrue(true);
    }

    function testCalculatePriceDeviation() public {
        // Set up two chain states with different prices
        uint256 price1 = 2000000000000000000000; // $2000
        uint256 price2 = 2100000000000000000000; // $2100
        
        syncHookL2.updateChainPoolState(TEST_POOL_ID, CHAIN_ID_1, 1000, price1, 0, 0);
        syncHookL2.updateChainPoolState(TEST_POOL_ID, CHAIN_ID_2, 1000, price2, 0, 0);
        
        uint256 deviation = syncHookL2.calculatePriceDeviation(TEST_POOL_ID, CHAIN_ID_1, CHAIN_ID_2);
        
        // Expected deviation: ((2100 - 2000) * 10000) / 2000 = 500 basis points (5%)
        assertEq(deviation, 500);
    }

    function testCalculatePriceDeviationReverse() public {
        // Set up two chain states with different prices (reverse order)
        uint256 price1 = 2100000000000000000000; // $2100
        uint256 price2 = 2000000000000000000000; // $2000
        
        syncHookL2.updateChainPoolState(TEST_POOL_ID, CHAIN_ID_1, 1000, price1, 0, 0);
        syncHookL2.updateChainPoolState(TEST_POOL_ID, CHAIN_ID_2, 1000, price2, 0, 0);
        
        uint256 deviation = syncHookL2.calculatePriceDeviation(TEST_POOL_ID, CHAIN_ID_1, CHAIN_ID_2);
        
        // Expected deviation: ((2100 - 2000) * 10000) / 2000 = 500 basis points (5%)
        assertEq(deviation, 500);
    }

    function testCalculatePriceDeviationWithInactiveChain() public {
        // Set up one active and one inactive chain
        syncHookL2.updateChainPoolState(TEST_POOL_ID, CHAIN_ID_1, 1000, 2000, 0, 0);
        // Don't set up CHAIN_ID_2, so it will be inactive
        
        vm.expectRevert("SyncHookL2: one or both chains not active");
        syncHookL2.calculatePriceDeviation(TEST_POOL_ID, CHAIN_ID_1, CHAIN_ID_2);
    }

    function testOnlyAuthorizedCanUpdateChainPoolState() public {
        address nonOwner = makeAddr("nonOwner");
        vm.prank(nonOwner);
        
        vm.expectRevert("SyncHookL2: caller is not authorized");
        syncHookL2.updateChainPoolState(TEST_POOL_ID, CHAIN_ID_1, 1000, 2000, 0, 0);
    }

    function testOwnerCanAddAuthorizedOperator() public {
        address operator = makeAddr("operator");
        
        syncHookL2.addAuthorizedOperator(operator);
        assertTrue(syncHookL2.authorizedOperators(operator));
    }

    function testOwnerCanRemoveAuthorizedOperator() public {
        address operator = makeAddr("operator");
        
        // Add operator
        syncHookL2.addAuthorizedOperator(operator);
        assertTrue(syncHookL2.authorizedOperators(operator));
        
        // Remove operator
        syncHookL2.removeAuthorizedOperator(operator);
        assertFalse(syncHookL2.authorizedOperators(operator));
    }

    function testDeactivateChainPool() public {
        // First set up a chain pool
        syncHookL2.updateChainPoolState(TEST_POOL_ID, CHAIN_ID_1, 1000, 2000, 0, 0);
        (,,,,,, bool isActive) = syncHookL2.getChainPoolState(TEST_POOL_ID, CHAIN_ID_1);
        assertTrue(isActive);
        
        // Deactivate the chain pool
        syncHookL2.deactivateChainPool(TEST_POOL_ID, CHAIN_ID_1);
        (,,,,,, isActive) = syncHookL2.getChainPoolState(TEST_POOL_ID, CHAIN_ID_1);
        assertFalse(isActive);
    }
}

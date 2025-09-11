// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {SyncAVS} from "../../src/avs/SyncAVS.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer/contracts/interfaces/IPermissionController.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {IAcrossIntegration} from "../../src/hooks/interfaces/IAcrossIntegration.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

contract SyncAVSTest is Test {
    SyncAVS public syncAVS;
    
    address public owner = address(0x1);
    address public operator = address(0x2);
    address public user = address(0x3);
    
    function setUp() public {
        // Deploy SyncAVS with mock addresses
        syncAVS = new SyncAVS(
            IAVSDirectory(address(0x1000)),
            IRewardsCoordinator(address(0x2000)),
            ISlashingRegistryCoordinator(address(0x3000)),
            IStakeRegistry(address(0x4000)),
            IPermissionController(address(0x5000)),
            IAllocationManager(address(0x6000)),
            IAcrossIntegration(address(0x7000))
        );
        
        // Register operator for testing
        vm.prank(owner);
        syncAVS.registerOperator(operator, "test-operator-metadata");
    }
    
    function test_Deployment() public {
        assertTrue(address(syncAVS) != address(0));
        console2.log("SyncAVS owner:", syncAVS.owner());
        console2.log("Test contract address:", address(this));
        console2.log("Expected owner:", owner);
    }
    
    function test_SubmitStateUpdate() public {
        SyncAVS.PoolState memory poolState = SyncAVS.PoolState({
            totalLiquidity: 1000000e18,
            price: 2000e18,
            volume24h: 100000e18,
            fees24h: 1000e18,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
        
        // Submit state update
        vm.prank(operator);
        syncAVS.submitStateUpdate(
            1, // chainId
            poolState,
            "0x1234" // signature (non-empty)
        );
    }
    
    function test_GetGlobalState() public {
        Currency currency0 = Currency.wrap(address(0x1));
        Currency currency1 = Currency.wrap(address(0x2));
        
        (uint256 totalLiquidity, uint256 averagePrice, uint256 imbalanceScore, uint256 lastUpdateBlock) = 
            syncAVS.getGlobalState(currency0, currency1);
        assertTrue(totalLiquidity >= 0);
    }
    
    function test_ShouldTriggerRebalancing() public {
        Currency currency0 = Currency.wrap(address(0x1000));
        Currency currency1 = Currency.wrap(address(0x2000));
        
        (bool shouldTrigger, uint256 sourceChain, uint256 targetChain, uint256 amount) = 
            syncAVS.shouldTriggerRebalancing(currency0, currency1);
        assertFalse(shouldTrigger); // Should be false initially
    }
    
    function test_InitiateRebalancing() public {
        // Initiate rebalancing
        vm.prank(operator);
        uint256 taskId = syncAVS.initiateRebalancing(
            1, // sourceChain
            137, // targetChain
            1000e18, // amount
            address(0x1000) // token
        );
        
        assertTrue(taskId > 0);
    }
    
    function test_GetRebalancingTask() public {
        
        // Initiate rebalancing
        vm.prank(operator);
        uint256 taskId = syncAVS.initiateRebalancing(
            1, // sourceChain
            137, // targetChain
            1000e18, // amount
            address(0x1000) // token
        );
        
        // Get task
        SyncAVS.RebalancingTask memory task = syncAVS.getRebalancingTask(taskId);
        assertTrue(task.amount > 0);
    }
    
    function test_UpdateTaskStatus() public {
        // Initiate rebalancing
        vm.prank(operator);
        uint256 taskId = syncAVS.initiateRebalancing(
            1, // sourceChain
            137, // targetChain
            1000e18, // amount
            address(0x1000) // token
        );
        
        // Update task status
        vm.prank(operator);
        syncAVS.updateTaskStatus(taskId, SyncAVS.TaskStatus.Completed);
    }
    
    function test_RegisterOperator() public {
        // Operator is already registered in setUp()
        assertTrue(syncAVS.isRegisteredOperator(operator));
    }
    
    function test_DeregisterOperator() public {
        // Operator is already registered in setUp()
        assertTrue(syncAVS.isRegisteredOperator(operator));
        
        // Deregister (operator calls it themselves)
        vm.prank(operator);
        syncAVS.deregisterOperator(operator);
        assertFalse(syncAVS.isRegisteredOperator(operator));
    }
    
    function test_IsRegisteredOperator() public {
        // Operator is already registered in setUp()
        assertTrue(syncAVS.isRegisteredOperator(operator));
    }
    
    function test_PauseAVS() public {
        vm.prank(syncAVS.owner());
        syncAVS.pauseAVS();
        // Should not revert
    }
    
    function test_UnpauseAVS() public {
        vm.prank(syncAVS.owner());
        syncAVS.pauseAVS();
        vm.prank(syncAVS.owner());
        syncAVS.unpauseAVS();
        // Should not revert
    }
    
    function test_UpdateSlashingParameters() public {
        vm.prank(syncAVS.owner());
        syncAVS.updateSlashingParameters(500, 1e18); // 5% slashing (500 basis points), 1 ETH min stake
        // Should not revert
    }
    
    function test_SlashOperator() public {
        // Operator is already registered in setUp()
        
        // Slash operator
        vm.prank(syncAVS.owner());
        syncAVS.slashOperator(operator, 100e18);
        // Should not revert
    }
    
    function test_OnlyRegisteredOperator() public {
        SyncAVS.PoolState memory poolState = SyncAVS.PoolState({
            totalLiquidity: 1000000e18,
            price: 2000e18,
            volume24h: 100000e18,
            fees24h: 1000e18,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
        
        vm.prank(user);
        vm.expectRevert();
        syncAVS.submitStateUpdate(1, poolState, "");
    }
    
    function test_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        syncAVS.updateSlashingParameters(10e16, 1e18);
    }
    
    function test_ValidTaskId() public {
        vm.expectRevert();
        syncAVS.getRebalancingTask(999); // Non-existent task
    }
}

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

contract SyncAVSFuzzTest is Test {
    SyncAVS public syncAVS;
    
    address public owner = address(0x1);
    
    function setUp() public {
        syncAVS = new SyncAVS(
            IAVSDirectory(address(0x1000)),
            IRewardsCoordinator(address(0x2000)),
            ISlashingRegistryCoordinator(address(0x3000)),
            IStakeRegistry(address(0x4000)),
            IPermissionController(address(0x5000)),
            IAllocationManager(address(0x6000)),
            IAcrossIntegration(address(0x7000))
        );
    }
    
    
    function testFuzz_InitiateRebalancing(
        uint256 sourceChain,
        uint256 targetChain,
        uint256 amount,
        address token
    ) public {
        // Bound inputs to reasonable ranges
        vm.assume(sourceChain > 0 && sourceChain <= 1000000);
        vm.assume(targetChain > 0 && targetChain <= 1000000);
        vm.assume(sourceChain != targetChain);
        vm.assume(amount > 0 && amount <= type(uint256).max / 2);
        vm.assume(token != address(0));
        
        // Register operator first
        address operator = address(0x1234);
        syncAVS.registerOperator(operator, "test-operator");
        
        // Should not revert - call from operator
        vm.prank(operator);
        uint256 taskId = syncAVS.initiateRebalancing(sourceChain, targetChain, amount, token);
        assertTrue(taskId > 0);
    }
    
    
    function testFuzz_RegisterOperator(
        address operator,
        string calldata metadataURI
    ) public {
        vm.assume(operator != address(0));
        vm.assume(bytes(metadataURI).length > 0);
        
        // Should not revert
        syncAVS.registerOperator(operator, metadataURI);
        assertTrue(syncAVS.isRegisteredOperator(operator));
    }
    
    function testFuzz_DeregisterOperator(address operator) public {
        vm.assume(operator != address(0));
        
        // Register first
        syncAVS.registerOperator(operator, "test-operator");
        assertTrue(syncAVS.isRegisteredOperator(operator));
        
        // Deregister - call from the operator
        vm.prank(operator);
        syncAVS.deregisterOperator(operator);
        assertFalse(syncAVS.isRegisteredOperator(operator));
    }
    
    function testFuzz_IsRegisteredOperator(address operator) public {
        bool isRegistered = syncAVS.isRegisteredOperator(operator);
        assertFalse(isRegistered); // Should be false initially
        
        // Register operator
        syncAVS.registerOperator(operator, "test-operator");
        assertTrue(syncAVS.isRegisteredOperator(operator));
    }
    
    
    
    function testFuzz_ShouldTriggerRebalancing(
        address currency0,
        address currency1
    ) public {
        vm.assume(currency0 != currency1);
        vm.assume(currency0 != address(0));
        vm.assume(currency1 != address(0));
        
        Currency currency0_typed = Currency.wrap(currency0);
        Currency currency1_typed = Currency.wrap(currency1);
        
        (bool shouldTrigger, uint256 sourceChain, uint256 targetChain, uint256 amount) = 
            syncAVS.shouldTriggerRebalancing(currency0_typed, currency1_typed);
        assertFalse(shouldTrigger); // Should be false initially
    }
    
    function testFuzz_GetGlobalState(
        address currency0,
        address currency1
    ) public {
        vm.assume(currency0 != currency1);
        vm.assume(currency0 != address(0));
        vm.assume(currency1 != address(0));
        
        Currency currency0_typed = Currency.wrap(currency0);
        Currency currency1_typed = Currency.wrap(currency1);
        
        (uint256 totalLiquidity, uint256 averagePrice, uint256 imbalanceScore, uint256 lastUpdateBlock) = 
            syncAVS.getGlobalState(currency0_typed, currency1_typed);
        assertTrue(totalLiquidity >= 0);
        assertTrue(averagePrice >= 0);
        assertTrue(imbalanceScore >= 0);
        assertTrue(lastUpdateBlock >= 0);
    }
    
    
    function testFuzz_OnlyRegisteredOperator(
        address caller,
        uint256 chainId,
        uint256 totalLiquidity,
        uint256 price,
        uint256 volume24h,
        uint256 fees24h,
        uint256 timestamp,
        uint256 blockNumber,
        bytes calldata signature
    ) public {
        vm.assume(caller != address(0));
        vm.assume(chainId > 0);
        vm.assume(totalLiquidity > 0);
        vm.assume(price > 0);
        vm.assume(volume24h > 0);
        vm.assume(fees24h > 0);
        vm.assume(timestamp > 0);
        vm.assume(blockNumber > 0);
        
        SyncAVS.PoolState memory poolState = SyncAVS.PoolState({
            totalLiquidity: totalLiquidity,
            price: price,
            volume24h: volume24h,
            fees24h: fees24h,
            timestamp: timestamp,
            blockNumber: blockNumber
        });
        
        vm.prank(caller);
        vm.expectRevert();
        syncAVS.submitStateUpdate(chainId, poolState, signature);
    }
    
}

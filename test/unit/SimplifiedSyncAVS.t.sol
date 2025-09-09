// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {SimplifiedSyncAVS} from "../../src/avs/SimplifiedSyncAVS.sol";
import {ISyncAVS} from "../../src/avs/interfaces/ISyncAVS.sol";
import {MockStateValidation} from "../helpers/MockStateValidation.sol";
import {Constants} from "../../src/utils/Constants.sol";
import {Errors} from "../../src/utils/Errors.sol";
import {Events} from "../../src/utils/Events.sol";

contract SimplifiedSyncAVSTest is Test {
    SimplifiedSyncAVS public avs;
    MockStateValidation public mockValidation;
    
    address public owner = makeAddr("owner");
    address public operator1 = makeAddr("operator1");
    address public operator2 = makeAddr("operator2");
    address public user1 = makeAddr("user1");
    
    bytes32 public constant POOL_ID_1 = keccak256("POOL_1");
    bytes32 public constant POOL_ID_2 = keccak256("POOL_2");
    
    function setUp() public {
        // Deploy mock validation
        mockValidation = new MockStateValidation();
        
        // Deploy SimplifiedSyncAVS
        vm.prank(owner);
        avs = new SimplifiedSyncAVS(address(mockValidation), owner);
        
        // Set up operators
        vm.prank(operator1);
        avs.registerOperator(operator1, "operator1-metadata");
        
        vm.prank(operator2);
        avs.registerOperator(operator2, "operator2-metadata");
    }
    
    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_Deployment() public {
        assertEq(avs.owner(), owner);
        assertEq(address(avs.stateValidation()), address(mockValidation));
        assertEq(avs.latestTaskNum(), 0);
        assertEq(avs.slashingPenaltyRate(), Constants.SLASHING_PENALTY_RATE);
        assertEq(avs.maxSlashingPenalty(), Constants.MAX_SLASHING_PENALTY);
        assertEq(avs.minimumStakeRequired(), Constants.OPERATOR_STAKE_MINIMUM);
        assertEq(avs.taskResponseWindow(), Constants.TASK_RESPONSE_WINDOW);
    }
    
    /*//////////////////////////////////////////////////////////////
                        OPERATOR MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_RegisterOperator() public {
        address newOperator = makeAddr("newOperator");
        string memory metadataURI = "new-operator-metadata";
        
        vm.expectEmit(true, false, false, true);
        emit Events.OperatorRegistered(newOperator, metadataURI, Constants.OPERATOR_STAKE_MINIMUM);
        
        vm.prank(newOperator);
        avs.registerOperator(newOperator, metadataURI);
        
        ISyncAVS.OperatorInfo memory info = avs.getOperatorInfo(newOperator);
        assertEq(info.operatorAddress, newOperator);
        assertEq(info.metadataURI, metadataURI);
        assertEq(info.stakeAmount, Constants.OPERATOR_STAKE_MINIMUM);
        assertEq(info.lastActiveBlock, block.number);
        assertTrue(info.isRegistered);
        assertEq(info.taskResponseCount, 0);
        assertEq(info.slashingCount, 0);
        
        assertTrue(avs.isValidOperator(newOperator));
    }
    
    function test_DeregisterOperator_ByOperator() public {
        vm.expectEmit(true, false, false, true);
        emit Events.OperatorDeregistered(operator1, "Voluntary deregistration");
        
        vm.prank(operator1);
        avs.deregisterOperator(operator1);
        
        ISyncAVS.OperatorInfo memory info = avs.getOperatorInfo(operator1);
        assertFalse(info.isRegistered);
        assertFalse(avs.isValidOperator(operator1));
    }
    
    function test_DeregisterOperator_ByOwner() public {
        vm.expectEmit(true, false, false, true);
        emit Events.OperatorDeregistered(operator1, "Voluntary deregistration");
        
        vm.prank(owner);
        avs.deregisterOperator(operator1);
        
        assertFalse(avs.isValidOperator(operator1));
    }
    
    function test_DeregisterOperator_Unauthorized() public {
        vm.prank(user1);
        vm.expectRevert("Not authorized");
        avs.deregisterOperator(operator1);
    }
    
    function test_SlashOperator() public {
        uint256 slashAmount = 1 ether;
        string memory reason = "Test slashing";
        
        vm.expectEmit(true, false, false, true);
        emit Events.OperatorSlashed(operator1, slashAmount, reason, block.timestamp);
        
        vm.prank(owner);
        avs.slashOperator(operator1, slashAmount, reason);
        
        ISyncAVS.OperatorInfo memory info = avs.getOperatorInfo(operator1);
        assertEq(info.stakeAmount, Constants.OPERATOR_STAKE_MINIMUM - slashAmount);
        assertEq(info.slashingCount, 1);
    }
    
    function test_SlashOperator_InvalidOperator() public {
        address invalidOperator = makeAddr("invalidOperator");
        
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidOperator.selector, invalidOperator));
        avs.slashOperator(invalidOperator, 1 ether, "test");
    }
    
    function test_SlashOperator_ExcessiveAmount() public {
        uint256 excessiveAmount = Constants.OPERATOR_STAKE_MINIMUM + 1 ether;
        
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(
            Errors.InvalidSlashingAmount.selector, 
            excessiveAmount, 
            Constants.OPERATOR_STAKE_MINIMUM
        ));
        avs.slashOperator(operator1, excessiveAmount, "test");
    }
    
    function test_SlashOperator_OnlyOwner() public {
        vm.prank(operator1);
        vm.expectRevert();
        avs.slashOperator(operator2, 1 ether, "unauthorized");
    }
    
    /*//////////////////////////////////////////////////////////////
                        TASK CREATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_CreateStateUpdateTask() public {
        uint256 chainId = 1;
        ISyncAVS.PoolState memory poolState = ISyncAVS.PoolState({
            totalLiquidity: 1000 ether,
            price: 1500 * 1e18,
            volume24h: 100 ether,
            fees24h: 1 ether,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
        
        bytes32 expectedTaskHash = keccak256(abi.encode(chainId, POOL_ID_1, poolState, block.timestamp));
        
        vm.expectEmit(true, true, false, true);
        emit Events.TaskCreated(1, expectedTaskHash, user1, block.number);
        
        vm.prank(user1);
        uint32 taskIndex = avs.createStateUpdateTask(chainId, POOL_ID_1, poolState);
        
        assertEq(taskIndex, 1);
        assertEq(avs.latestTaskNum(), 1);
        
        ISyncAVS.TaskMetadata memory metadata = avs.getTaskMetadata(taskIndex);
        assertEq(metadata.taskIndex, taskIndex);
        assertEq(metadata.taskCreatedBlock, block.number);
        assertEq(metadata.taskHash, expectedTaskHash);
        assertEq(metadata.taskDeadline, block.timestamp + Constants.TASK_RESPONSE_WINDOW);
        assertEq(metadata.taskCreator, user1);
    }
    
    function test_CreateStateUpdateTask_WhenPaused() public {
        vm.prank(owner);
        avs.pauseAVS();
        
        ISyncAVS.PoolState memory poolState = ISyncAVS.PoolState({
            totalLiquidity: 1000 ether,
            price: 1500 * 1e18,
            volume24h: 100 ether,
            fees24h: 1 ether,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
        
        vm.prank(user1);
        vm.expectRevert(Errors.EmergencyPaused.selector);
        avs.createStateUpdateTask(1, POOL_ID_1, poolState);
    }
    
    function test_CreateRebalancingTask() public {
        uint256 sourceChain = 1;
        uint256 targetChain = 137;
        address token = makeAddr("token");
        uint256 amount = 100 ether;
        
        bytes32 expectedRequestId = keccak256(abi.encode(sourceChain, targetChain, token, amount, block.timestamp));
        
        vm.expectEmit(true, true, true, true);
        emit Events.RebalancingTaskCreated(expectedRequestId, sourceChain, targetChain, amount);
        
        vm.prank(user1);
        bytes32 requestId = avs.createRebalancingTask(sourceChain, targetChain, token, amount);
        
        assertEq(requestId, expectedRequestId);
        
        ISyncAVS.RebalancingTask memory task = avs.getRebalancingTask(requestId);
        assertEq(task.requestId, requestId);
        assertEq(task.sourceChain, sourceChain);
        assertEq(task.targetChain, targetChain);
        assertEq(task.token, token);
        assertEq(task.amount, amount);
        assertEq(task.deadline, block.timestamp + Constants.TASK_RESPONSE_WINDOW);
        assertTrue(task.status == ISyncAVS.TaskStatus.PENDING);
    }
    
    /*//////////////////////////////////////////////////////////////
                        TASK RESPONSE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_RespondToStateUpdateTask() public {
        // Create task
        ISyncAVS.PoolState memory poolState = ISyncAVS.PoolState({
            totalLiquidity: 1000 ether,
            price: 1500 * 1e18,
            volume24h: 100 ether,
            fees24h: 1 ether,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
        
        vm.prank(user1);
        uint32 taskIndex = avs.createStateUpdateTask(1, POOL_ID_1, poolState);
        
        // Respond to task
        ISyncAVS.StateUpdateTask memory taskResponse = ISyncAVS.StateUpdateTask({
            chainId: 1,
            poolId: POOL_ID_1,
            poolState: poolState,
            timestamp: block.timestamp,
            operatorSignature: ""
        });
        
        bytes memory signature = new bytes(65); // Valid signature length
        bytes32 expectedResponseHash = keccak256(abi.encode(taskResponse));
        
        vm.expectEmit(true, true, false, true);
        emit Events.TaskResponded(taskIndex, operator1, expectedResponseHash, block.timestamp);
        
        vm.prank(operator1);
        avs.respondToStateUpdateTask(taskIndex, taskResponse, signature);
        
        assertTrue(avs.taskResponses(taskIndex, operator1));
        
        ISyncAVS.OperatorInfo memory info = avs.getOperatorInfo(operator1);
        assertEq(info.taskResponseCount, 1);
    }
    
    function test_RespondToStateUpdateTask_TaskNotFound() public {
        ISyncAVS.StateUpdateTask memory taskResponse = ISyncAVS.StateUpdateTask({
            chainId: 1,
            poolId: POOL_ID_1,
            poolState: ISyncAVS.PoolState({
                totalLiquidity: 1000 ether,
                price: 1500 * 1e18,
                volume24h: 100 ether,
                fees24h: 1 ether,
                timestamp: block.timestamp,
                blockNumber: block.number
            }),
            timestamp: block.timestamp,
            operatorSignature: ""
        });
        
        vm.prank(operator1);
        vm.expectRevert(abi.encodeWithSelector(Errors.TaskNotFound.selector, 999));
        avs.respondToStateUpdateTask(999, taskResponse, new bytes(65));
    }
    
    function test_RespondToStateUpdateTask_TaskExpired() public {
        // Create task
        ISyncAVS.PoolState memory poolState = ISyncAVS.PoolState({
            totalLiquidity: 1000 ether,
            price: 1500 * 1e18,
            volume24h: 100 ether,
            fees24h: 1 ether,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
        
        vm.prank(user1);
        uint32 taskIndex = avs.createStateUpdateTask(1, POOL_ID_1, poolState);
        
        // Move time forward beyond deadline
        vm.warp(block.timestamp + Constants.TASK_RESPONSE_WINDOW + 1);
        
        ISyncAVS.StateUpdateTask memory taskResponse = ISyncAVS.StateUpdateTask({
            chainId: 1,
            poolId: POOL_ID_1,
            poolState: poolState,
            timestamp: block.timestamp,
            operatorSignature: ""
        });
        
        // Verify operator1 is still registered  
        assertTrue(avs.isValidOperator(operator1), "operator1 should be registered");
        
        // Get the task deadline that was set during creation
        ISyncAVS.TaskMetadata memory taskMetadata = avs.getTaskMetadata(taskIndex);
        
        // Use startPrank/stopPrank for more reliable pranking
        vm.startPrank(operator1);
        vm.expectRevert(abi.encodeWithSelector(
            Errors.TaskExpired.selector,
            taskMetadata.taskDeadline,
            block.timestamp
        ));
        avs.respondToStateUpdateTask(taskIndex, taskResponse, new bytes(65));
        vm.stopPrank();
    }
    
    function test_RespondToStateUpdateTask_AlreadyResponded() public {
        // Create task
        ISyncAVS.PoolState memory poolState = ISyncAVS.PoolState({
            totalLiquidity: 1000 ether,
            price: 1500 * 1e18,
            volume24h: 100 ether,
            fees24h: 1 ether,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
        
        vm.prank(user1);
        uint32 taskIndex = avs.createStateUpdateTask(1, POOL_ID_1, poolState);
        
        ISyncAVS.StateUpdateTask memory taskResponse = ISyncAVS.StateUpdateTask({
            chainId: 1,
            poolId: POOL_ID_1,
            poolState: poolState,
            timestamp: block.timestamp,
            operatorSignature: ""
        });
        
        // Respond once
        vm.prank(operator1);
        avs.respondToStateUpdateTask(taskIndex, taskResponse, new bytes(65));
        
        // Try to respond again
        vm.prank(operator1);
        vm.expectRevert(abi.encodeWithSelector(Errors.TaskAlreadyResponded.selector, taskIndex));
        avs.respondToStateUpdateTask(taskIndex, taskResponse, new bytes(65));
    }
    
    function test_RespondToStateUpdateTask_NotRegisteredOperator() public {
        address unregisteredOperator = makeAddr("unregistered");
        
        // Create task
        ISyncAVS.PoolState memory poolState = ISyncAVS.PoolState({
            totalLiquidity: 1000 ether,
            price: 1500 * 1e18,
            volume24h: 100 ether,
            fees24h: 1 ether,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
        
        vm.prank(user1);
        uint32 taskIndex = avs.createStateUpdateTask(1, POOL_ID_1, poolState);
        
        ISyncAVS.StateUpdateTask memory taskResponse = ISyncAVS.StateUpdateTask({
            chainId: 1,
            poolId: POOL_ID_1,
            poolState: poolState,
            timestamp: block.timestamp,
            operatorSignature: ""
        });
        
        vm.prank(unregisteredOperator);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidOperator.selector, unregisteredOperator));
        avs.respondToStateUpdateTask(taskIndex, taskResponse, new bytes(65));
    }
    
    /*//////////////////////////////////////////////////////////////
                        REBALANCING TASK TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_ExecuteRebalancingTask() public {
        // Create rebalancing task
        vm.prank(user1);
        bytes32 requestId = avs.createRebalancingTask(1, 137, makeAddr("token"), 100 ether);
        
        vm.expectEmit(true, false, false, true);
        emit Events.RebalancingExecuted(requestId, 0, 100 ether, 0, block.timestamp);
        
        vm.prank(operator1);
        avs.executeRebalancingTask(requestId);
        
        ISyncAVS.RebalancingTask memory task = avs.getRebalancingTask(requestId);
        assertTrue(task.status == ISyncAVS.TaskStatus.COMPLETED);
    }
    
    function test_ExecuteRebalancingTask_AlreadyInProgress() public {
        vm.prank(user1);
        bytes32 requestId = avs.createRebalancingTask(1, 137, makeAddr("token"), 100 ether);
        
        // Execute once
        vm.prank(operator1);
        avs.executeRebalancingTask(requestId);
        
        // Try to execute again
        vm.prank(operator2);
        vm.expectRevert(Errors.RebalancingInProgress.selector);
        avs.executeRebalancingTask(requestId);
    }
    
    function test_ExecuteRebalancingTask_Expired() public {
        vm.prank(user1);
        bytes32 requestId = avs.createRebalancingTask(1, 137, makeAddr("token"), 100 ether);
        
        // Move time forward beyond deadline
        vm.warp(block.timestamp + Constants.TASK_RESPONSE_WINDOW + 1);
        
        vm.prank(operator1);
        avs.executeRebalancingTask(requestId);
        
        ISyncAVS.RebalancingTask memory task = avs.getRebalancingTask(requestId);
        assertTrue(task.status == ISyncAVS.TaskStatus.EXPIRED);
    }
    
    /*//////////////////////////////////////////////////////////////
                        STATE QUERY TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_GetGlobalPoolState() public {
        // Create and respond to a task to populate state
        ISyncAVS.PoolState memory poolState = ISyncAVS.PoolState({
            totalLiquidity: 1000 ether,
            price: 1500 * 1e18,
            volume24h: 100 ether,
            fees24h: 1 ether,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
        
        vm.prank(user1);
        uint32 taskIndex = avs.createStateUpdateTask(1, POOL_ID_1, poolState);
        
        ISyncAVS.StateUpdateTask memory taskResponse = ISyncAVS.StateUpdateTask({
            chainId: 1,
            poolId: POOL_ID_1,
            poolState: poolState,
            timestamp: block.timestamp,
            operatorSignature: ""
        });
        
        vm.prank(operator1);
        avs.respondToStateUpdateTask(taskIndex, taskResponse, new bytes(65));
        
        (
            uint256 totalLiquidity,
            uint256 averagePrice,
            uint256 imbalanceScore,
            uint256 supportedChainsCount,
            uint256 lastUpdateBlock
        ) = avs.getGlobalPoolState(POOL_ID_1);
        
        assertEq(totalLiquidity, 1000 ether);
        assertEq(averagePrice, 1500 * 1e18);
        assertEq(lastUpdateBlock, block.number);
    }
    
    function test_GetAggregatedMetrics() public {
        ISyncAVS.AggregatedMetrics memory metrics = avs.getAggregatedMetrics(POOL_ID_1);
        
        // Should return default values for non-existent pool
        assertEq(metrics.totalLiquidity, 0);
        assertEq(metrics.weightedAveragePrice, 0);
        assertEq(metrics.maxImbalance, 0);
        assertEq(metrics.priceVariance, 0);
        assertEq(metrics.liquidityDistribution, 0);
        assertEq(metrics.lastCalculationBlock, 0);
    }
    
    /*//////////////////////////////////////////////////////////////
                        CONFIGURATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_UpdateSlashingParameters() public {
        uint256 newPenaltyRate = 75000; // 7.5%
        uint256 newMaxPenalty = 15 ether;
        
        vm.prank(owner);
        avs.updateSlashingParameters(newPenaltyRate, newMaxPenalty);
        
        assertEq(avs.slashingPenaltyRate(), newPenaltyRate);
        assertEq(avs.maxSlashingPenalty(), newMaxPenalty);
    }
    
    function test_UpdateSlashingParameters_ExcessivePenalty() public {
        uint256 excessivePenaltyRate = Constants.MAX_SLASHING_PENALTY + 1;
        
        vm.prank(owner);
        vm.expectRevert(Errors.InvalidThreshold.selector);
        avs.updateSlashingParameters(excessivePenaltyRate, 15 ether);
    }
    
    function test_UpdateSlashingParameters_OnlyOwner() public {
        vm.prank(operator1);
        vm.expectRevert();
        avs.updateSlashingParameters(75000, 15 ether);
    }
    
    /*//////////////////////////////////////////////////////////////
                        EMERGENCY CONTROL TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_PauseAVS() public {
        assertFalse(avs.paused());
        
        vm.expectEmit(true, false, false, true);
        emit Events.EmergencyPaused(owner, "AVS paused", block.timestamp);
        
        vm.prank(owner);
        avs.pauseAVS();
        
        assertTrue(avs.paused());
    }
    
    function test_UnpauseAVS() public {
        vm.prank(owner);
        avs.pauseAVS();
        assertTrue(avs.paused());
        
        vm.expectEmit(true, false, false, true);
        emit Events.EmergencyUnpaused(owner, block.timestamp);
        
        vm.prank(owner);
        avs.unpauseAVS();
        
        assertFalse(avs.paused());
    }
    
    function test_PauseAVS_OnlyOwner() public {
        vm.prank(operator1);
        vm.expectRevert();
        avs.pauseAVS();
    }
    
    function test_UnpauseAVS_OnlyOwner() public {
        vm.prank(owner);
        avs.pauseAVS();
        
        vm.prank(operator1);
        vm.expectRevert();
        avs.unpauseAVS();
    }
    
    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_FullTaskLifecycle() public {
        // Create task
        ISyncAVS.PoolState memory poolState = ISyncAVS.PoolState({
            totalLiquidity: 1000 ether,
            price: 1500 * 1e18,
            volume24h: 100 ether,
            fees24h: 1 ether,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
        
        vm.prank(user1);
        uint32 taskIndex = avs.createStateUpdateTask(1, POOL_ID_1, poolState);
        
        // Multiple operators respond
        ISyncAVS.StateUpdateTask memory taskResponse = ISyncAVS.StateUpdateTask({
            chainId: 1,
            poolId: POOL_ID_1,
            poolState: poolState,
            timestamp: block.timestamp,
            operatorSignature: ""
        });
        
        vm.prank(operator1);
        avs.respondToStateUpdateTask(taskIndex, taskResponse, new bytes(65));
        
        vm.prank(operator2);
        avs.respondToStateUpdateTask(taskIndex, taskResponse, new bytes(65));
        
        // Check that both operators responded
        assertTrue(avs.taskResponses(taskIndex, operator1));
        assertTrue(avs.taskResponses(taskIndex, operator2));
        
        // Check response counts
        assertEq(avs.getOperatorInfo(operator1).taskResponseCount, 1);
        assertEq(avs.getOperatorInfo(operator2).taskResponseCount, 1);
        
        // Check global state was updated
        (uint256 totalLiquidity,,,, uint256 lastUpdateBlock) = avs.getGlobalPoolState(POOL_ID_1);
        assertEq(totalLiquidity, 1000 ether);
        assertEq(lastUpdateBlock, block.number);
    }
    
    function test_ValidationFailureHandling() public {
        // Configure mock to fail validation
        mockValidation.setValidationResult(false, "Invalid state", 0);
        
        // Create task
        ISyncAVS.PoolState memory poolState = ISyncAVS.PoolState({
            totalLiquidity: 1000 ether,
            price: 1500 * 1e18,
            volume24h: 100 ether,
            fees24h: 1 ether,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
        
        vm.prank(user1);
        uint32 taskIndex = avs.createStateUpdateTask(1, POOL_ID_1, poolState);
        
        ISyncAVS.StateUpdateTask memory taskResponse = ISyncAVS.StateUpdateTask({
            chainId: 1,
            poolId: POOL_ID_1,
            poolState: poolState,
            timestamp: block.timestamp,
            operatorSignature: ""
        });
        
        // Expect validation failure event
        vm.expectEmit(true, false, false, true);
        emit Events.StateValidationFailed(operator1, taskIndex, "Invalid state", block.timestamp);
        
        vm.prank(operator1);
        avs.respondToStateUpdateTask(taskIndex, taskResponse, new bytes(65));
        
        // Check that slashing count increased
        assertEq(avs.getOperatorInfo(operator1).slashingCount, 1);
        
        // Task response should not be recorded
        assertFalse(avs.taskResponses(taskIndex, operator1));
    }
}
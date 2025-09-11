// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {SyncTaskManager} from "../../src/avs/SyncTaskManager.sol";

contract SyncTaskManagerTest is Test {
    SyncTaskManager public taskManager;
    
    address public owner = address(0x1);
    address public operator = address(0x2);
    address public user = address(0x3);
    
    function setUp() public {
        taskManager = new SyncTaskManager(
            address(0x1000), // syncAVS
            address(0x2000), // stateValidation
            0.001e18, // taskCreationFee
            0.005e18, // taskCompletionReward
            0.01e18   // taskFailurePenalty
        );
    }
    
    function test_Deployment() public {
        assertTrue(address(taskManager) != address(0));
        assertEq(taskManager.taskCreationFee(), 0.001e18);
        assertEq(taskManager.taskCompletionReward(), 0.005e18);
        assertEq(taskManager.taskFailurePenalty(), 0.01e18);
    }
    
    function test_CreateTask() public {
        uint256 taskId = taskManager.createTask{value: 0.001e18}(
            1, // taskType: StateUpdate
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId: Ethereum
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
        
        assertTrue(taskId > 0);
        
        SyncTaskManager.Task memory task = taskManager.getTask(taskId);
        assertEq(uint256(task.taskType), 1);
        assertEq(uint256(task.priority), 1); // Medium
        assertEq(task.chainId, 1);
        assertEq(uint256(task.status), 0); // Pending
    }
    
    function test_CreateTaskInsufficientFee() public {
        vm.expectRevert("Insufficient creation fee");
        taskManager.createTask{value: 0.0001e18}(
            1, // taskType
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
    }
    
    function test_CreateTaskInvalidType() public {
        vm.expectRevert("Invalid task type");
        taskManager.createTask{value: 0.001e18}(
            0, // Invalid task type
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
    }
    
    function test_CreateTaskPaused() public {
        taskManager.pauseTaskCreation();
        
        vm.expectRevert("Task creation paused");
        taskManager.createTask{value: 0.001e18}(
            1, // taskType
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
    }
    
    function test_AssignTask() public {
        uint256 taskId = taskManager.createTask{value: 0.001e18}(
            1, // taskType
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
        
        taskManager.assignTask(taskId, operator);
        
        SyncTaskManager.Task memory task = taskManager.getTask(taskId);
        assertEq(task.assignedOperator, operator);
        assertEq(uint256(task.status), 1); // Assigned
    }
    
    function test_StartTask() public {
        uint256 taskId = taskManager.createTask{value: 0.001e18}(
            1, // taskType
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
        
        taskManager.assignTask(taskId, operator);
        
        vm.prank(operator);
        taskManager.startTask(taskId);
        
        SyncTaskManager.Task memory task = taskManager.getTask(taskId);
        assertEq(uint256(task.status), 2); // InProgress
    }
    
    function test_CompleteTask() public {
        uint256 taskId = taskManager.createTask{value: 0.001e18}(
            1, // taskType
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
        
        taskManager.assignTask(taskId, operator);
        
        vm.prank(operator);
        taskManager.startTask(taskId);
        
        vm.prank(operator);
        taskManager.completeTask(taskId, "result");
        
        SyncTaskManager.Task memory task = taskManager.getTask(taskId);
        assertEq(uint256(task.status), 3); // Completed
    }
    
    function test_FailTask() public {
        uint256 taskId = taskManager.createTask{value: 0.001e18}(
            1, // taskType
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
        
        taskManager.assignTask(taskId, operator);
        
        vm.prank(operator);
        taskManager.startTask(taskId);
        
        vm.prank(operator);
        taskManager.failTask(taskId, "error");
        
        SyncTaskManager.Task memory task = taskManager.getTask(taskId);
        assertEq(uint256(task.status), 4); // Failed
    }
    
    function test_CancelTask() public {
        uint256 taskId = taskManager.createTask{value: 0.001e18}(
            1, // taskType
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
        
        taskManager.cancelTask(taskId, "cancelled");
        
        SyncTaskManager.Task memory task = taskManager.getTask(taskId);
        assertEq(uint256(task.status), 5); // Cancelled
    }
    
    function test_CheckTimeouts() public {
        uint256 taskId = taskManager.createTask{value: 0.001e18}(
            1, // taskType
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            1 // Very short timeout
        );
        
        taskManager.assignTask(taskId, operator);
        
        vm.prank(operator);
        taskManager.startTask(taskId);
        
        // Fast forward time
        vm.warp(block.timestamp + 2);
        
        uint256[] memory taskIds = new uint256[](1);
        taskIds[0] = taskId;
        
        taskManager.checkTimeouts(taskIds);
        
        SyncTaskManager.Task memory task = taskManager.getTask(taskId);
        assertEq(uint256(task.status), 6); // Timeout
    }
    
    function test_GetOperatorTasks() public {
        uint256 taskId = taskManager.createTask{value: 0.001e18}(
            1, // taskType
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
        
        taskManager.assignTask(taskId, operator);
        
        uint256[] memory operatorTasks = taskManager.getOperatorTasks(operator);
        assertEq(operatorTasks.length, 1);
        assertEq(operatorTasks[0], taskId);
    }
    
    function test_GetChainTasks() public {
        uint256 taskId = taskManager.createTask{value: 0.001e18}(
            1, // taskType
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
        
        uint256[] memory chainTasks = taskManager.getChainTasks(1);
        assertEq(chainTasks.length, 1);
        assertEq(chainTasks[0], taskId);
    }
    
    function test_GetTasksByType() public {
        uint256 taskId = taskManager.createTask{value: 0.001e18}(
            1, // taskType
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
        
        uint256[] memory tasksByType = taskManager.getTasksByType(1);
        assertEq(tasksByType.length, 1);
        assertEq(tasksByType[0], taskId);
    }
    
    function test_GetAllTasks() public {
        uint256 taskId = taskManager.createTask{value: 0.001e18}(
            1, // taskType
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
        
        uint256[] memory allTasks = taskManager.getAllTasks();
        assertEq(allTasks.length, 1);
        assertEq(allTasks[0], taskId);
    }
    
    function test_GetTaskStatistics() public {
        uint256 taskId = taskManager.createTask{value: 0.001e18}(
            1, // taskType
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
        
        // Check that task was created
        SyncTaskManager.Task memory task = taskManager.getTask(taskId);
        assertEq(uint256(task.status), 0); // Pending
        assertEq(task.assignedOperator, address(0)); // Not assigned yet
    }
    
    function test_UpdateTaskConfig() public {
        taskManager.updateTaskConfig(
            0.002e18, // new creation fee
            0.01e18,  // new completion reward
            0.02e18   // new failure penalty
        );
        
        assertEq(taskManager.taskCreationFee(), 0.002e18);
        assertEq(taskManager.taskCompletionReward(), 0.01e18);
        assertEq(taskManager.taskFailurePenalty(), 0.02e18);
    }
    
    function test_PauseTaskCreation() public {
        taskManager.pauseTaskCreation();
        assertTrue(taskManager.taskCreationPaused());
    }
    
    function test_ResumeTaskCreation() public {
        taskManager.pauseTaskCreation();
        taskManager.resumeTaskCreation();
        assertFalse(taskManager.taskCreationPaused());
    }
    
    function test_Pause() public {
        taskManager.pause();
        // Should not revert
    }
    
    function test_Unpause() public {
        taskManager.pause();
        taskManager.unpause();
        // Should not revert
    }
    
    function test_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        taskManager.updateTaskConfig(0.002e18, 0.01e18, 0.02e18);
    }
    
    function test_OnlyAssignedOperator() public {
        uint256 taskId = taskManager.createTask{value: 0.001e18}(
            1, // taskType
            SyncTaskManager.TaskPriority.Medium,
            1, // chainId
            bytes32(0), // poolId
            "", // payload
            3600 // timeout
        );
        
        taskManager.assignTask(taskId, operator);
        
        vm.prank(user);
        vm.expectRevert();
        taskManager.startTask(taskId);
    }
    
    function test_ValidTaskId() public {
        vm.expectRevert();
        taskManager.getTask(999); // Non-existent task
    }
}

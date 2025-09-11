// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ISyncAVS} from "../../src/hooks/interfaces/ISyncAVS.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

contract MockSyncAVS is ISyncAVS {
    function getGlobalState(
        Currency currency0,
        Currency currency1
    ) external view override returns (
        uint256 totalLiquidity,
        uint256 averagePrice,
        uint256 imbalanceScore,
        uint256 lastUpdateBlock
    ) {
        return (1000000e18, 2000e18, 100, block.number);
    }
    
    function submitStateUpdate(
        uint256 chainId,
        PoolState calldata poolState,
        bytes calldata signature
    ) external {
        // Mock implementation
    }
    
    function triggerRebalancing(
        Currency currency0,
        Currency currency1,
        uint256 targetAmount,
        uint256 targetChain
    ) external {
        // Mock implementation
    }
    
    function shouldTriggerRebalancing(
        Currency currency0,
        Currency currency1
    ) external pure returns (
        bool shouldTrigger,
        uint256 sourceChain,
        uint256 targetChain,
        uint256 amount
    ) {
        return (false, 0, 0, 0);
    }
    
    function initiateRebalancing(
        uint256 sourceChain,
        uint256 targetChain,
        uint256 amount,
        address token
    ) external returns (uint256 taskId) {
        return 1;
    }
    
    function getRebalancingTask(uint256 taskId) external view returns (RebalancingTask memory) {
        return RebalancingTask({
            taskId: taskId,
            sourceChain: 1,
            targetChain: 1,
            amount: 0,
            token: address(0),
            deadline: block.timestamp + 1 days,
            status: ISyncAVS.TaskStatus.Pending
        });
    }
    
    function updateTaskStatus(uint256 taskId, ISyncAVS.TaskStatus status) external {
        // Mock implementation
    }
    
    function registerOperator(address operator, string calldata metadataURI) external {
        // Mock implementation
    }
    
    function deregisterOperator(address operator) external {
        // Mock implementation
    }
    
    function isRegisteredOperator(address operator) external pure returns (bool) {
        return true;
    }
    
    function pauseAVS() external {
        // Mock implementation
    }
    
    function unpauseAVS() external {
        // Mock implementation
    }
    
    function slashOperator(address operator, uint256 amount) external {
        // Mock implementation
    }
    
    function updateSlashingParameters(uint256 newSlashingPercentage, uint256 newMinStake) external {
        // Mock implementation
    }
}

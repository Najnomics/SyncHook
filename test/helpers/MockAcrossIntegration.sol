// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IAcrossIntegration} from "../../src/hooks/interfaces/IAcrossIntegration.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

abstract contract MockAcrossIntegration is IAcrossIntegration {
    function requestRebalancing(
        address token,
        address counterToken,
        uint256 imbalanceAmount
    ) external returns (bytes32 requestId) {
        return bytes32(uint256(1)); // Mock request ID
    }
    
    function executeRebalancing(bytes32 requestId) external {
        // Mock implementation
    }
    
    function getRebalancingRequest(bytes32 requestId) external view returns (RebalancingRequest memory) {
        return RebalancingRequest({
            sourceChain: 1,
            targetChain: 1,
            token: address(0),
            amount: 0,
            timestamp: block.timestamp,
            executed: false
        });
    }
    
    function isRebalancingInProgress(
        address token,
        address counterToken
    ) external pure returns (bool) {
        return false;
    }
    
    function calculateOptimalRebalancing(
        address token,
        address counterToken,
        uint256 imbalanceAmount
    ) external pure returns (uint256 targetChain, uint256 transferAmount) {
        return (1, 0);
    }
    
    function spokePool() external pure returns (address) {
        return address(0);
    }
    
    function getSupportedChains() external pure returns (uint256[] memory) {
        uint256[] memory chains = new uint256[](1);
        chains[0] = 1;
        return chains;
    }
    
    function isChainSupported(uint256 chainId) external pure returns (bool) {
        return chainId == 1;
    }
    
    function addSupportedChain(uint256 chainId) external {
        // Mock implementation
    }
    
    function removeSupportedChain(uint256 chainId) external {
        // Mock implementation
    }
    
    function updateAcrossConfig(address newSpokePool, address newRelayer) external {
        // Mock implementation
    }
    
    function pauseRebalancing() external {
        // Mock implementation
    }
    
    function resumeRebalancing() external {
        // Mock implementation
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IStateAggregator} from "../../src/hooks/interfaces/IStateAggregator.sol";

/**
 * @title MockStateAggregator
 * @notice Mock implementation of IStateAggregator for testing
 */
contract MockStateAggregator is IStateAggregator {
    mapping(bytes32 => mapping(uint256 => ChainPoolState)) public chainStates;
    mapping(uint256 => bool) public supportedChains;
    mapping(address => bool) public authorizedCallers;
    
    function aggregatePoolStates(bytes32) external view override returns (AggregatedMetrics memory) {
        return AggregatedMetrics({
            totalLiquidity: 1000 ether,
            averagePrice: 2000e18,
            maxImbalance: 1000, // 10%
            supportedChains: 3,
            lastUpdate: block.timestamp
        });
    }
    
    function updateChainState(bytes32 poolKey, uint256 chainId, ChainPoolState memory state) external override {
        chainStates[poolKey][chainId] = state;
    }
    
    function getChainState(bytes32 poolKey, uint256 chainId) external view override returns (ChainPoolState memory) {
        return chainStates[poolKey][chainId];
    }
    
    function getPoolState(bytes32, uint256) external view override returns (
        uint256 liquidity,
        uint256 price,
        uint256 volume24h,
        uint256 fees24h,
        uint256 timestamp,
        uint256 blockNumber
    ) {
        return (1000 ether, 2000e18, 500 ether, 1 ether, block.timestamp, block.number);
    }
    
    function addSupportedChain(uint256 chainId) external override {
        supportedChains[chainId] = true;
    }
    
    function removeSupportedChain(uint256 chainId) external override {
        supportedChains[chainId] = false;
    }
    
    function isSupportedChain(uint256 chainId) external view override returns (bool) {
        return supportedChains[chainId];
    }
    
    function addAuthorizedCaller(address caller) external override {
        authorizedCallers[caller] = true;
    }
    
    function removeAuthorizedCaller(address caller) external override {
        authorizedCallers[caller] = false;
    }
    
    function isAuthorizedCaller(address caller) external view override returns (bool) {
        return authorizedCallers[caller];
    }
    
    // Stub implementations for other required functions
    function getRebalancingRecommendation(bytes32) external pure override returns (RebalancingRecommendation memory) {
        return RebalancingRecommendation(0, 0, 0, 0, 0, 0);
    }
    
    function calculateOptimalRebalancing(bytes32, uint256, uint256, uint256) external pure override returns (uint256, uint256) {
        return (0, 0);
    }
    
    function shouldTriggerRebalancing(bytes32, uint256) external pure override returns (bool, uint256) {
        return (false, 0);
    }
    
    function validateStateConsistency(bytes32, uint256, uint256) external pure override returns (ValidationResult memory) {
        string[] memory empty;
        return ValidationResult(true, 10000, empty, empty);
    }
    
    function detectAnomalies(bytes32, uint256) external pure override returns (bool, string[] memory, uint256) {
        string[] memory empty;
        return (false, empty, 0);
    }
    
    function configureChain(uint256, uint256, bool) external override {}
    
    function removeChain(uint256 chainId) external override {
        supportedChains[chainId] = false;
    }
    
    function getChainInfo(uint256) external pure override returns (ChainInfo memory) {
        return ChainInfo(0, false, 0, 0, 0);
    }
    
    function getSupportedChains() external pure override returns (uint256[] memory) {
        uint256[] memory chains = new uint256[](0);
        return chains;
    }
    
    function updateAggregationParams(uint256, uint256, uint256) external override {}
    
    function getHistoricalMetrics(bytes32, uint256, uint256) external pure override returns (
        uint256[] memory,
        uint256[] memory,
        uint256[] memory,
        uint256[] memory
    ) {
        uint256[] memory empty = new uint256[](0);
        return (empty, empty, empty, empty);
    }
    
    function getPerformanceStats() external pure override returns (uint256, uint256, uint256, uint256, uint256) {
        return (0, 0, 0, 0, 0);
    }
}
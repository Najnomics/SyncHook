// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SyncHookL1
 * @dev L1 contract for SyncHook cross-chain liquidity synchronization
 * This contract manages pool state updates and coordinates with L2 contracts
 */
contract SyncHookL1 {
    string private constant VERSION = "SyncHook L1 v1.0.0";
    
    // Pool state management
    struct PoolState {
        uint256 totalLiquidity;
        uint256 averagePrice;
        uint256 imbalanceScore;
        uint64 lastUpdateBlock;
        uint64 timestamp;
        bool isActive;
    }
    
    // Pool states mapping
    mapping(bytes32 => PoolState) public poolStates;
    
    // Events
    event PoolStateUpdated(bytes32 indexed poolId, uint256 totalLiquidity, uint256 averagePrice, uint256 imbalanceScore);
    event RebalancingTriggered(bytes32 indexed poolId, uint256 amount, uint32 targetChainId);
    event CrossChainSyncInitiated(bytes32 indexed poolId, uint32 sourceChainId, uint32 targetChainId, uint256 amount);
    
    // Access control
    address public owner;
    mapping(address => bool) public authorizedOperators;
    
    modifier onlyOwner() {
        require(msg.sender == owner, "SyncHookL1: caller is not the owner");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedOperators[msg.sender] || msg.sender == owner, "SyncHookL1: caller is not authorized");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Get the contract version
     */
    function getVersion() public pure returns (string memory) {
        return VERSION;
    }
    
    /**
     * @dev Update pool state
     * @param poolId The unique identifier for the pool
     * @param totalLiquidity Total liquidity in the pool
     * @param averagePrice Average price across chains
     * @param imbalanceScore Current imbalance score
     */
    function updatePoolState(
        bytes32 poolId,
        uint256 totalLiquidity,
        uint256 averagePrice,
        uint256 imbalanceScore
    ) external onlyAuthorized {
        poolStates[poolId] = PoolState({
            totalLiquidity: totalLiquidity,
            averagePrice: averagePrice,
            imbalanceScore: imbalanceScore,
            lastUpdateBlock: uint64(block.number),
            timestamp: uint64(block.timestamp),
            isActive: true
        });
        
        emit PoolStateUpdated(poolId, totalLiquidity, averagePrice, imbalanceScore);
    }
    
    /**
     * @dev Get current pool state
     * @param poolId The pool identifier
     */
    function getPoolState(bytes32 poolId) external view returns (PoolState memory) {
        return poolStates[poolId];
    }
    
    /**
     * @dev Trigger rebalancing for a pool
     * @param poolId The pool identifier
     * @param amount Amount to rebalance
     * @param targetChainId Target chain for rebalancing
     */
    function triggerRebalancing(
        bytes32 poolId,
        uint256 amount,
        uint32 targetChainId
    ) external onlyAuthorized {
        require(poolStates[poolId].isActive, "SyncHookL1: pool not active");
        
        emit RebalancingTriggered(poolId, amount, targetChainId);
    }
    
    /**
     * @dev Initiate cross-chain synchronization
     * @param poolId The pool identifier
     * @param sourceChainId Source chain ID
     * @param targetChainId Target chain ID
     * @param amount Amount to sync
     */
    function initiateCrossChainSync(
        bytes32 poolId,
        uint32 sourceChainId,
        uint32 targetChainId,
        uint256 amount
    ) external onlyAuthorized {
        require(poolStates[poolId].isActive, "SyncHookL1: pool not active");
        require(sourceChainId != targetChainId, "SyncHookL1: source and target chains must be different");
        
        emit CrossChainSyncInitiated(poolId, sourceChainId, targetChainId, amount);
    }
    
    /**
     * @dev Add authorized operator
     * @param operator The operator address
     */
    function addAuthorizedOperator(address operator) external onlyOwner {
        authorizedOperators[operator] = true;
    }
    
    /**
     * @dev Remove authorized operator
     * @param operator The operator address
     */
    function removeAuthorizedOperator(address operator) external onlyOwner {
        authorizedOperators[operator] = false;
    }
    
    /**
     * @dev Deactivate a pool
     * @param poolId The pool identifier
     */
    function deactivatePool(bytes32 poolId) external onlyOwner {
        poolStates[poolId].isActive = false;
    }
}


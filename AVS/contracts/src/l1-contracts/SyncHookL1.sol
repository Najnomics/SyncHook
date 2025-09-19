// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SyncHookL1
 * @dev L1 contract for SyncHook cross-chain liquidity synchronization
 * This contract manages global pool state aggregation and coordinates with L2 contracts
 * Part of the SyncHook ecosystem for Uniswap V4 cross-chain liquidity management
 */
contract SyncHookL1 is Ownable, Pausable, ReentrancyGuard {
    string private constant VERSION = "SyncHook L1 v2.0.0";
    
    // Global pool state management
    struct GlobalPoolState {
        uint256 totalLiquidity;
        uint256 averagePrice;
        uint256 priceVariance;
        uint256 imbalanceScore;
        uint256 totalVolume24h;
        uint256 totalFees24h;
        uint64 lastUpdateBlock;
        uint64 timestamp;
        uint32 activeChains;
        bool isActive;
    }
    
    // Chain-specific pool state
    struct ChainPoolState {
        uint256 liquidity;
        uint256 price;
        uint256 volume24h;
        uint256 fees24h;
        uint64 lastUpdateBlock;
        uint64 timestamp;
        bool isActive;
    }
    
    // Global pool states mapping
    mapping(bytes32 => GlobalPoolState) public globalPoolStates;
    
    // Chain-specific pool states mapping
    mapping(bytes32 => mapping(uint32 => ChainPoolState)) public chainPoolStates;
    
    // Supported chains
    mapping(uint32 => bool) public supportedChains;
    uint32[] public supportedChainIds;
    
    // Events
    event GlobalPoolStateUpdated(
        bytes32 indexed poolId, 
        uint256 totalLiquidity, 
        uint256 averagePrice, 
        uint256 priceVariance,
        uint256 imbalanceScore,
        uint32 activeChains
    );
    event ChainPoolStateUpdated(
        bytes32 indexed poolId, 
        uint32 indexed chainId, 
        uint256 liquidity, 
        uint256 price
    );
    event RebalancingTriggered(
        bytes32 indexed poolId, 
        uint256 amount, 
        uint32 targetChainId,
        uint256 priceDeviation
    );
    event CrossChainSyncInitiated(
        bytes32 indexed poolId, 
        uint32 sourceChainId, 
        uint32 targetChainId, 
        uint256 amount
    );
    event ChainAdded(uint32 indexed chainId);
    event ChainRemoved(uint32 indexed chainId);
    event OperatorAuthorized(address indexed operator);
    event OperatorDeauthorized(address indexed operator);
    
    // Access control
    mapping(address => bool) public authorizedOperators;
    mapping(address => bool) public authorizedValidators;
    
    modifier onlyAuthorized() {
        require(
            authorizedOperators[msg.sender] || 
            authorizedValidators[msg.sender] || 
            msg.sender == owner, 
            "SyncHookL1: caller is not authorized"
        );
        _;
    }
    
    constructor() Ownable(msg.sender) {
        // Initialize with supported chains
        _addSupportedChain(1); // Ethereum
        _addSupportedChain(42161); // Arbitrum
        _addSupportedChain(137); // Polygon
        _addSupportedChain(8453); // Base
        _addSupportedChain(10); // Optimism
    }
    
    /**
     * @dev Get the contract version
     */
    function getVersion() public pure returns (string memory) {
        return VERSION;
    }
    
    /**
     * @dev Update global pool state (aggregated from all chains)
     * @param poolId The unique identifier for the pool
     * @param totalLiquidity Total liquidity across all chains
     * @param averagePrice Average price across all chains
     * @param priceVariance Price variance across chains
     * @param imbalanceScore Current global imbalance score
     * @param totalVolume24h Total 24h volume across all chains
     * @param totalFees24h Total 24h fees across all chains
     * @param activeChains Number of active chains
     */
    function updateGlobalPoolState(
        bytes32 poolId,
        uint256 totalLiquidity,
        uint256 averagePrice,
        uint256 priceVariance,
        uint256 imbalanceScore,
        uint256 totalVolume24h,
        uint256 totalFees24h,
        uint32 activeChains
    ) external onlyAuthorized whenNotPaused {
        globalPoolStates[poolId] = GlobalPoolState({
            totalLiquidity: totalLiquidity,
            averagePrice: averagePrice,
            priceVariance: priceVariance,
            imbalanceScore: imbalanceScore,
            totalVolume24h: totalVolume24h,
            totalFees24h: totalFees24h,
            lastUpdateBlock: uint64(block.number),
            timestamp: uint64(block.timestamp),
            activeChains: activeChains,
            isActive: true
        });
        
        emit GlobalPoolStateUpdated(
            poolId, 
            totalLiquidity, 
            averagePrice, 
            priceVariance,
            imbalanceScore,
            activeChains
        );
    }
    
    /**
     * @dev Update chain-specific pool state
     * @param poolId The unique identifier for the pool
     * @param chainId The chain identifier
     * @param liquidity Current liquidity on this chain
     * @param price Current price on this chain
     * @param volume24h 24-hour volume on this chain
     * @param fees24h 24-hour fees on this chain
     */
    function updateChainPoolState(
        bytes32 poolId,
        uint32 chainId,
        uint256 liquidity,
        uint256 price,
        uint256 volume24h,
        uint256 fees24h
    ) external onlyAuthorized whenNotPaused {
        require(supportedChains[chainId], "SyncHookL1: chain not supported");
        
        chainPoolStates[poolId][chainId] = ChainPoolState({
            liquidity: liquidity,
            price: price,
            volume24h: volume24h,
            fees24h: fees24h,
            lastUpdateBlock: uint64(block.number),
            timestamp: uint64(block.timestamp),
            isActive: true
        });
        
        emit ChainPoolStateUpdated(poolId, chainId, liquidity, price);
    }
    
    /**
     * @dev Get current global pool state
     * @param poolId The pool identifier
     */
    function getGlobalPoolState(bytes32 poolId) external view returns (GlobalPoolState memory) {
        return globalPoolStates[poolId];
    }
    
    /**
     * @dev Get chain-specific pool state
     * @param poolId The pool identifier
     * @param chainId The chain identifier
     */
    function getChainPoolState(bytes32 poolId, uint32 chainId) external view returns (ChainPoolState memory) {
        return chainPoolStates[poolId][chainId];
    }
    
    /**
     * @dev Calculate price deviation between chains
     * @param poolId The pool identifier
     * @param chainId1 First chain ID
     * @param chainId2 Second chain ID
     */
    function calculatePriceDeviation(
        bytes32 poolId,
        uint32 chainId1,
        uint32 chainId2
    ) external view returns (uint256 deviation) {
        ChainPoolState memory state1 = chainPoolStates[poolId][chainId1];
        ChainPoolState memory state2 = chainPoolStates[poolId][chainId2];
        
        require(state1.isActive && state2.isActive, "SyncHookL1: one or both chains not active");
        
        if (state1.price > state2.price) {
            deviation = ((state1.price - state2.price) * 10000) / state2.price; // Basis points
        } else {
            deviation = ((state2.price - state1.price) * 10000) / state1.price; // Basis points
        }
    }
    
    /**
     * @dev Trigger rebalancing for a pool
     * @param poolId The pool identifier
     * @param amount Amount to rebalance
     * @param targetChainId Target chain for rebalancing
     * @param priceDeviation Price deviation that triggered rebalancing
     */
    function triggerRebalancing(
        bytes32 poolId,
        uint256 amount,
        uint32 targetChainId,
        uint256 priceDeviation
    ) external onlyAuthorized whenNotPaused {
        require(globalPoolStates[poolId].isActive, "SyncHookL1: pool not active");
        require(supportedChains[targetChainId], "SyncHookL1: target chain not supported");
        
        emit RebalancingTriggered(poolId, amount, targetChainId, priceDeviation);
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
    ) external onlyAuthorized whenNotPaused {
        require(globalPoolStates[poolId].isActive, "SyncHookL1: pool not active");
        require(sourceChainId != targetChainId, "SyncHookL1: source and target chains must be different");
        require(supportedChains[sourceChainId] && supportedChains[targetChainId], "SyncHookL1: unsupported chain");
        
        emit CrossChainSyncInitiated(poolId, sourceChainId, targetChainId, amount);
    }
    
    /**
     * @dev Add supported chain
     * @param chainId The chain identifier
     */
    function addSupportedChain(uint32 chainId) external onlyOwner {
        _addSupportedChain(chainId);
    }
    
    /**
     * @dev Remove supported chain
     * @param chainId The chain identifier
     */
    function removeSupportedChain(uint32 chainId) external onlyOwner {
        require(supportedChains[chainId], "SyncHookL1: chain not supported");
        supportedChains[chainId] = false;
        
        // Remove from array
        for (uint256 i = 0; i < supportedChainIds.length; i++) {
            if (supportedChainIds[i] == chainId) {
                supportedChainIds[i] = supportedChainIds[supportedChainIds.length - 1];
                supportedChainIds.pop();
                break;
            }
        }
        
        emit ChainRemoved(chainId);
    }
    
    /**
     * @dev Get all supported chain IDs
     */
    function getSupportedChainIds() external view returns (uint32[] memory) {
        return supportedChainIds;
    }
    
    /**
     * @dev Add authorized operator
     * @param operator The operator address
     */
    function addAuthorizedOperator(address operator) external onlyOwner {
        authorizedOperators[operator] = true;
        emit OperatorAuthorized(operator);
    }
    
    /**
     * @dev Remove authorized operator
     * @param operator The operator address
     */
    function removeAuthorizedOperator(address operator) external onlyOwner {
        authorizedOperators[operator] = false;
        emit OperatorDeauthorized(operator);
    }
    
    /**
     * @dev Add authorized validator
     * @param validator The validator address
     */
    function addAuthorizedValidator(address validator) external onlyOwner {
        authorizedValidators[validator] = true;
    }
    
    /**
     * @dev Remove authorized validator
     * @param validator The validator address
     */
    function removeAuthorizedValidator(address validator) external onlyOwner {
        authorizedValidators[validator] = false;
    }
    
    /**
     * @dev Deactivate a global pool
     * @param poolId The pool identifier
     */
    function deactivateGlobalPool(bytes32 poolId) external onlyOwner {
        globalPoolStates[poolId].isActive = false;
    }
    
    /**
     * @dev Deactivate a chain pool
     * @param poolId The pool identifier
     * @param chainId The chain identifier
     */
    function deactivateChainPool(bytes32 poolId, uint32 chainId) external onlyOwner {
        chainPoolStates[poolId][chainId].isActive = false;
    }
    
    /**
     * @dev Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Internal function to add supported chain
     * @param chainId The chain identifier
     */
    function _addSupportedChain(uint32 chainId) internal {
        require(!supportedChains[chainId], "SyncHookL1: chain already supported");
        supportedChains[chainId] = true;
        supportedChainIds.push(chainId);
        emit ChainAdded(chainId);
    }
}


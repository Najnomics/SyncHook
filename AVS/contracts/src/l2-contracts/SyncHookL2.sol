// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SyncHookL2
 * @dev L2 contract for SyncHook cross-chain liquidity synchronization
 * This contract handles L2-specific operations and coordinates with L1 contracts
 * Part of the SyncHook ecosystem for Uniswap V4 cross-chain liquidity management
 */
contract SyncHookL2 is Ownable, Pausable, ReentrancyGuard {
    string private constant VERSION = "SyncHook L2 v2.0.0";
    
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
    
    // Rebalancing request
    struct RebalancingRequest {
        bytes32 poolId;
        uint32 sourceChainId;
        uint32 targetChainId;
        uint256 amount;
        uint256 priceDeviation;
        uint64 timestamp;
        bool isExecuted;
        bytes32 txHash;
    }
    
    // Pool states per chain
    mapping(bytes32 => mapping(uint32 => ChainPoolState)) public chainPoolStates;
    
    // Rebalancing requests
    mapping(bytes32 => RebalancingRequest) public rebalancingRequests;
    bytes32[] public rebalancingRequestIds;
    
    // Chain configuration
    uint32 public immutable chainId;
    mapping(uint32 => bool) public supportedChains;
    uint32[] public supportedChainIds;
    
    // Events
    event ChainPoolStateUpdated(bytes32 indexed poolId, uint32 chainId, uint256 liquidity, uint256 price);
    event LiquidityRebalanced(bytes32 indexed poolId, uint32 fromChainId, uint32 toChainId, uint256 amount);
    event CrossChainTransferCompleted(bytes32 indexed poolId, uint32 chainId, uint256 amount, bytes32 txHash);
    event RebalancingRequestCreated(bytes32 indexed requestId, bytes32 indexed poolId, uint32 sourceChainId, uint32 targetChainId, uint256 amount);
    event RebalancingRequestExecuted(bytes32 indexed requestId, bytes32 txHash);
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
            "SyncHookL2: caller is not authorized"
        );
        _;
    }
    
    constructor(uint32 _chainId) Ownable(msg.sender) {
        chainId = _chainId;
        
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
     * @dev Update chain-specific pool state
     * @param poolId The unique identifier for the pool
     * @param chainId The chain identifier
     * @param liquidity Current liquidity on this chain
     * @param price Current price on this chain
     * @param volume24h 24-hour volume
     * @param fees24h 24-hour fees
     */
    function updateChainPoolState(
        bytes32 poolId,
        uint32 chainId,
        uint256 liquidity,
        uint256 price,
        uint256 volume24h,
        uint256 fees24h
    ) external onlyAuthorized {
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
     * @dev Get chain-specific pool state
     * @param poolId The pool identifier
     * @param chainId The chain identifier
     */
    function getChainPoolState(bytes32 poolId, uint32 chainId) external view returns (ChainPoolState memory) {
        return chainPoolStates[poolId][chainId];
    }
    
    /**
     * @dev Record liquidity rebalancing
     * @param poolId The pool identifier
     * @param fromChainId Source chain ID
     * @param toChainId Target chain ID
     * @param amount Amount rebalanced
     */
    function recordLiquidityRebalancing(
        bytes32 poolId,
        uint32 fromChainId,
        uint32 toChainId,
        uint256 amount
    ) external onlyAuthorized {
        emit LiquidityRebalanced(poolId, fromChainId, toChainId, amount);
    }
    
    /**
     * @dev Record cross-chain transfer completion
     * @param poolId The pool identifier
     * @param chainId The chain identifier
     * @param amount Amount transferred
     * @param txHash Transaction hash
     */
    function recordCrossChainTransferCompletion(
        bytes32 poolId,
        uint32 chainId,
        uint256 amount,
        bytes32 txHash
    ) external onlyAuthorized {
        emit CrossChainTransferCompleted(poolId, chainId, amount, txHash);
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
        
        require(state1.isActive && state2.isActive, "SyncHookL2: one or both chains not active");
        
        if (state1.price > state2.price) {
            deviation = ((state1.price - state2.price) * 10000) / state2.price; // Basis points
        } else {
            deviation = ((state2.price - state1.price) * 10000) / state1.price; // Basis points
        }
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
     * @dev Deactivate a chain pool
     * @param poolId The pool identifier
     * @param chainId The chain identifier
     */
    function deactivateChainPool(bytes32 poolId, uint32 chainId) external onlyOwner {
        chainPoolStates[poolId][chainId].isActive = false;
    }
}


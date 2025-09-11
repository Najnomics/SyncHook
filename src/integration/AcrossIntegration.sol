// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAcrossIntegration} from "../hooks/interfaces/IAcrossIntegration.sol";
import {CrossChainUtils} from "./libraries/CrossChainUtils.sol";
import {LiquidityCalculations} from "./libraries/LiquidityCalculations.sol";

/**
 * @title AcrossIntegration
 * @notice Integration contract for Across Protocol cross-chain liquidity movement
 * @dev Handles rebalancing requests and executes cross-chain transfers via Across
 */
contract AcrossIntegration is IAcrossIntegration, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using CrossChainUtils for CrossChainUtils.ChainConfig;
    using LiquidityCalculations for LiquidityCalculations.PoolLiquidityState;

    /// @notice Across Protocol SpokePool contract
    address public immutable spokePool;
    
    /// @notice SyncAVS contract for coordination
    address public immutable syncAVS;
    
    /// @notice Bridge fee percentage (in basis points)
    uint256 public bridgeFeeBps;
    
    /// @notice Maximum rebalancing amount per request
    uint256 public maxRebalancingAmount;
    
    /// @notice Minimum rebalancing amount per request
    uint256 public minRebalancingAmount;
    
    /// @notice Rebalancing cooldown period (in blocks)
    uint256 public rebalancingCooldown;
    
    /// @notice Emergency pause for rebalancing
    bool public rebalancingPaused;
    
    /// @notice Mapping of request ID to rebalancing request
    mapping(bytes32 => RebalancingRequest) public rebalancingRequests;
    
    /// @notice Mapping of token to counter-token for rebalancing pairs
    mapping(address => address) public rebalancingPairs;
    
    /// @notice Mapping of chain ID to supported status
    mapping(uint256 => bool) public supportedChains;
    
    /// @notice Mapping of token to supported status
    mapping(address => bool) public supportedTokens;
    
    /// @notice Mapping of last rebalancing time per token pair
    mapping(address => mapping(address => uint256)) public lastRebalancingTime;
    
    /// @notice Array of supported chain IDs
    uint256[] public supportedChainIds;
    
    /// @notice Array of supported token addresses
    address[] public supportedTokensList;
    
    /// @notice Rebalancing request counter
    uint256 public requestCounter;

    /**
     * @notice Constructor
     * @param _spokePool Across Protocol SpokePool address
     * @param _syncAVS SyncAVS contract address
     * @param _bridgeFeeBps Bridge fee in basis points (e.g., 10 = 0.1%)
     * @param _maxRebalancingAmount Maximum rebalancing amount
     * @param _minRebalancingAmount Minimum rebalancing amount
     * @param _rebalancingCooldown Rebalancing cooldown in blocks
     */
    constructor(
        address _spokePool,
        address _syncAVS,
        uint256 _bridgeFeeBps,
        uint256 _maxRebalancingAmount,
        uint256 _minRebalancingAmount,
        uint256 _rebalancingCooldown
    ) Ownable(msg.sender) {
        require(_spokePool != address(0), "Invalid spoke pool");
        require(_syncAVS != address(0), "Invalid sync AVS");
        require(_bridgeFeeBps <= 1000, "Bridge fee too high"); // Max 10%
        
        spokePool = _spokePool;
        syncAVS = _syncAVS;
        bridgeFeeBps = _bridgeFeeBps;
        maxRebalancingAmount = _maxRebalancingAmount;
        minRebalancingAmount = _minRebalancingAmount;
        rebalancingCooldown = _rebalancingCooldown;
    }

    /**
     * @notice Request rebalancing between chains
     * @param token Token to rebalance
     * @param counterToken Counter token for the pair
     * @param imbalanceAmount Amount of imbalance to rebalance
     * @return requestId Unique request identifier
     */
    function requestRebalancing(
        address token,
        address counterToken,
        uint256 imbalanceAmount
    ) external override onlySyncAVS whenNotPaused nonReentrant returns (bytes32 requestId) {
        require(token != address(0), "Invalid token");
        require(counterToken != address(0), "Invalid counter token");
        require(imbalanceAmount >= minRebalancingAmount, "Amount too small");
        require(imbalanceAmount <= maxRebalancingAmount, "Amount too large");
        require(supportedTokens[token], "Token not supported");
        require(supportedTokens[counterToken], "Counter token not supported");
        
        // Check cooldown
        require(
            block.number >= lastRebalancingTime[token][counterToken] + rebalancingCooldown,
            "Rebalancing cooldown active"
        );
        
        // Calculate optimal rebalancing
        (uint256 targetChain, uint256 transferAmount) = calculateOptimalRebalancing(
            token,
            counterToken,
            imbalanceAmount
        );
        
        require(transferAmount > 0, "No rebalancing needed");
        require(supportedChains[targetChain], "Target chain not supported");
        
        // Generate request ID
        requestId = keccak256(abi.encodePacked(
            block.chainid,
            targetChain,
            token,
            transferAmount,
            block.timestamp,
            requestCounter++
        ));
        
        // Create rebalancing request
        rebalancingRequests[requestId] = RebalancingRequest({
            sourceChain: block.chainid,
            targetChain: targetChain,
            token: token,
            amount: transferAmount,
            timestamp: block.timestamp,
            executed: false
        });
        
        // Update last rebalancing time
        lastRebalancingTime[token][counterToken] = block.number;
        
        // Execute rebalancing
        _executeRebalancing(requestId);
        
        emit RebalancingRequested(requestId, targetChain, transferAmount);
    }

    /**
     * @notice Execute rebalancing via Across Protocol
     * @param requestId Request identifier
     */
    function executeRebalancing(bytes32 requestId) external override onlyOwner {
        _executeRebalancing(requestId);
    }

    /**
     * @notice Get rebalancing request details
     * @param requestId Request identifier
     * @return request Rebalancing request details
s      */
    function getRebalancingRequest(bytes32 requestId) external view override returns (RebalancingRequest memory request) {
        return rebalancingRequests[requestId];
    }

    /**
     * @notice Check if rebalancing is in progress for a token pair
     * @param token Token address
     * @param counterToken Counter token address
     * @return inProgress True if rebalancing is in progress
     */
    function isRebalancingInProgress(address token, address counterToken) external view override returns (bool inProgress) {
        // Check if cooldown is still active
        return block.number < lastRebalancingTime[token][counterToken] + rebalancingCooldown;
    }

    /**
     * @notice Calculate optimal rebalancing parameters
     * @param token Token to rebalance
     * @param counterToken Counter token for the pair
     * @param imbalanceAmount Amount of imbalance
     * @return targetChain Optimal target chain
     * @return transferAmount Optimal transfer amount
     */
    function calculateOptimalRebalancing(
        address token,
        address counterToken,
        uint256 imbalanceAmount
    ) public view override returns (uint256 targetChain, uint256 transferAmount) {
        // Simple implementation - in reality would use more sophisticated algorithms
        // Find the chain with the lowest liquidity for this token
        uint256 minLiquidity = type(uint256).max;
        uint256 optimalChain = 0;
        
        for (uint256 i = 0; i < supportedChainIds.length; i++) {
            uint256 chainId = supportedChainIds[i];
            if (chainId != block.chainid && supportedChains[chainId]) {
                // In a real implementation, this would query actual liquidity data
                // For now, use a simple heuristic
                uint256 estimatedLiquidity = 1000000 * 1e18; // Placeholder
                
                if (estimatedLiquidity < minLiquidity) {
                    minLiquidity = estimatedLiquidity;
                    optimalChain = chainId;
                }
            }
        }
        
        targetChain = optimalChain;
        transferAmount = imbalanceAmount / 2; // Move half of the imbalance
        
        // Ensure transfer amount is within bounds
        if (transferAmount < minRebalancingAmount) {
            transferAmount = minRebalancingAmount;
        }
        if (transferAmount > maxRebalancingAmount) {
            transferAmount = maxRebalancingAmount;
        }
    }

    /**
     * @notice Get supported chains
     * @return chains Array of supported chain IDs
     */
    function getSupportedChains() external view override returns (uint256[] memory chains) {
        return supportedChainIds;
    }

    /**
     * @notice Check if a chain is supported
     * @param chainId Chain ID to check
     * @return supported True if chain is supported
     */
    function isChainSupported(uint256 chainId) external view override returns (bool supported) {
        return supportedChains[chainId];
    }

    /**
     * @notice Add supported chain
     * @param chainId Chain ID to add
     */
    function addSupportedChain(uint256 chainId) external onlyOwner {
        require(!supportedChains[chainId], "Chain already supported");
        
        supportedChains[chainId] = true;
        supportedChainIds.push(chainId);
        
        emit ChainAdded(chainId);
    }

    /**
     * @notice Remove supported chain
     * @param chainId Chain ID to remove
     */
    function removeSupportedChain(uint256 chainId) external onlyOwner {
        require(supportedChains[chainId], "Chain not supported");
        
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
     * @notice Update Across Protocol configuration
     * @param _bridgeFeeBps New bridge fee in basis points
     * @param _maxRebalancingAmount New maximum rebalancing amount
     * @param _minRebalancingAmount New minimum rebalancing amount
     * @param _rebalancingCooldown New rebalancing cooldown
     */
    function updateAcrossConfig(
        uint256 _bridgeFeeBps,
        uint256 _maxRebalancingAmount,
        uint256 _minRebalancingAmount,
        uint256 _rebalancingCooldown
    ) external onlyOwner {
        require(_bridgeFeeBps <= 1000, "Bridge fee too high");
        require(_maxRebalancingAmount > _minRebalancingAmount, "Invalid amounts");
        
        bridgeFeeBps = _bridgeFeeBps;
        maxRebalancingAmount = _maxRebalancingAmount;
        minRebalancingAmount = _minRebalancingAmount;
        rebalancingCooldown = _rebalancingCooldown;
        
        emit ConfigUpdated(_bridgeFeeBps, _maxRebalancingAmount, _minRebalancingAmount, _rebalancingCooldown);
    }

    /**
     * @notice Add a supported token for rebalancing
     * @param token The token address to add
     */
    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(!supportedTokens[token], "Token already supported");
        
        supportedTokens[token] = true;
        emit TokenAdded(token);
    }

    /**
     * @notice Remove a supported token for rebalancing
     * @param token The token address to remove
     */
    function removeSupportedToken(address token) external onlyOwner {
        require(supportedTokens[token], "Token not supported");
        
        supportedTokens[token] = false;
        emit TokenRemoved(token);
    }

    /**
     * @notice Pause rebalancing
     */
    function pauseRebalancing() external onlyOwner {
        rebalancingPaused = true;
        emit RebalancingPaused();
    }

    /**
     * @notice Resume rebalancing
     */
    function resumeRebalancing() external onlyOwner {
        rebalancingPaused = false;
        emit RebalancingResumed();
    }

    /**
     * @notice Emergency pause
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Emergency unpause
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Update Across Protocol configuration
     * @param newSpokePool New SpokePool address
     * @param newRelayer New relayer address
     */
    function updateAcrossConfig(address newSpokePool, address newRelayer) external onlyOwner {
        require(newSpokePool != address(0), "Invalid spoke pool");
        // Note: This is a simplified implementation
        // In reality, you would update the spokePool and relayer addresses
        emit ConfigUpdated(bridgeFeeBps, maxRebalancingAmount, minRebalancingAmount, rebalancingCooldown);
    }

    // ============ Internal Functions ============

    /**
     * @notice Execute rebalancing via Across Protocol
     * @param requestId Request identifier
     */
    function _executeRebalancing(bytes32 requestId) internal {
        RebalancingRequest storage request = rebalancingRequests[requestId];
        require(request.amount > 0, "Invalid request");
        require(!request.executed, "Already executed");
        
        // Check if rebalancing is paused
        require(!rebalancingPaused, "Rebalancing paused");
        
        // Transfer tokens to this contract
        IERC20 token = IERC20(request.token);
        token.safeTransferFrom(msg.sender, address(this), request.amount);
        
        // Approve SpokePool to spend tokens
        token.forceApprove(spokePool, request.amount);
        
        // Execute deposit via Across Protocol
        // Note: This is a simplified implementation
        // In reality, you would call the actual SpokePool.deposit function
        _executeAcrossDeposit(request);
        
        request.executed = true;
        
        emit RebalancingExecuted(requestId, request.targetChain, request.amount);
    }

    /**
     * @notice Execute Across Protocol deposit
     * @param request Rebalancing request
     */
    function _executeAcrossDeposit(RebalancingRequest memory request) internal {
        // This is a placeholder implementation
        // In reality, you would call:
        // ISpokePool(spokePool).deposit(
        //     address(this),                    // depositor
        //     address(this),                    // recipient
        //     request.token,                    // inputToken
        //     request.token,                    // outputToken
        //     request.amount,                   // inputAmount
        //     request.amount * (10000 - bridgeFeeBps) / 10000, // outputAmount
        //     request.targetChain,              // destinationChainId
        //     address(0),                       // exclusiveRelayer
        //     uint32(block.timestamp),          // quoteTimestamp
        //     uint32(block.timestamp + 3600),   // fillDeadline
        //     0,                                // exclusivityDeadline
        //     ""                                // message
        // );
        
        // For now, just emit an event
        emit AcrossDepositInitiated(
            request.sourceChain,
            request.targetChain,
            request.token,
            request.amount
        );
    }

    // ============ Modifiers ============

    modifier onlySyncAVS() {
        require(msg.sender == syncAVS, "Only SyncAVS");
        _;
    }

    // ============ Events ============

    event RebalancingExecuted(bytes32 indexed requestId, uint256 targetChain, uint256 amount);
    event ChainAdded(uint256 indexed chainId);
    event ChainRemoved(uint256 indexed chainId);
    event ConfigUpdated(uint256 bridgeFeeBps, uint256 maxRebalancingAmount, uint256 minRebalancingAmount, uint256 rebalancingCooldown);
    event RebalancingPaused();
    event RebalancingResumed();
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event AcrossDepositInitiated(uint256 sourceChain, uint256 targetChain, address token, uint256 amount);
}

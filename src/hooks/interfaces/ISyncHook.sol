// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

/**
 * @title ISyncHook
 * @author SyncHook Team
 * @notice Interface for the SyncHook Uniswap V4 Hook
 * @dev Defines core hook functionality and cross-chain state management
 */

interface ISyncHook {
    // ============================================================================
    // STRUCTS
    // ============================================================================
    
    /**
     * @notice Pool state information for a specific chain
     * @param totalLiquidity Total liquidity in the pool
     * @param price Current price of the pool
     * @param volume24h 24-hour trading volume
     * @param fees24h 24-hour collected fees
     * @param timestamp Last update timestamp
     * @param blockNumber Block number of last update
     */
    struct PoolState {
        uint256 totalLiquidity;
        uint256 price;
        uint256 volume24h;
        uint256 fees24h;
        uint256 timestamp;
        uint256 blockNumber;
    }
    
    /**
     * @notice Global pool state across all supported chains
     * @param chainStates Mapping from chain ID to pool state
     * @param totalLiquidity Aggregated total liquidity
     * @param averagePrice Weighted average price
     * @param imbalanceScore Maximum imbalance score across chains
     * @param supportedChainsCount Number of supported chains
     * @param lastUpdateBlock Block number of last update
     */
    struct GlobalPoolState {
        mapping(uint256 => PoolState) chainStates;
        uint256 totalLiquidity;
        uint256 averagePrice;
        uint256 imbalanceScore;
        uint256 supportedChainsCount;
        uint256 lastUpdateBlock;
    }
    
    /**
     * @notice Optimization parameters for swap execution
     * @param dynamicFeeAdjustment Fee adjustment based on imbalance
     * @param liquidityBonus Bonus for providing needed liquidity
     * @param priceImpactReduction Reduced price impact factor
     * @param gasOptimization Gas optimization suggestion
     */
    struct OptimizationParams {
        int256 dynamicFeeAdjustment;
        uint256 liquidityBonus;
        uint256 priceImpactReduction;
        uint256 gasOptimization;
    }
    
    /**
     * @notice Rebalancing trigger information
     * @param shouldTrigger Whether rebalancing should be triggered
     * @param sourceChain Chain to move liquidity from
     * @param targetChain Chain to move liquidity to
     * @param amount Amount to rebalance
     * @param urgency Urgency level (0-100)
     */
    struct RebalancingTrigger {
        bool shouldTrigger;
        uint256 sourceChain;
        uint256 targetChain;
        uint256 amount;
        uint256 urgency;
    }
    
    // ============================================================================
    // HOOK LIFECYCLE FUNCTIONS
    // ============================================================================
    
    /**
     * @notice Called before a swap is executed
     * @param poolKey The pool key
     * @param swapParams Swap parameters
     * @param hookData Additional hook data
     * @return OptimizationParams Suggested optimizations
     */
    function beforeSwap(
        bytes32 poolKey,
        SwapParams calldata swapParams,
        bytes calldata hookData
    ) external returns (OptimizationParams memory);
    
    /**
     * @notice Called after a swap is executed
     * @param poolKey The pool key
     * @param swapParams Swap parameters
     * @param hookData Additional hook data
     */
    function afterSwap(
        bytes32 poolKey,
        SwapParams calldata swapParams,
        bytes calldata hookData
    ) external;
    
    /**
     * @notice Called after liquidity is added
     * @param poolKey The pool key
     * @param params Liquidity modification parameters
     * @param hookData Additional hook data
     */
    function afterAddLiquidity(
        bytes32 poolKey,
        LiquidityParams calldata params,
        bytes calldata hookData
    ) external;
    
    /**
     * @notice Called after liquidity is removed
     * @param poolKey The pool key
     * @param params Liquidity modification parameters
     * @param hookData Additional hook data
     */
    function afterRemoveLiquidity(
        bytes32 poolKey,
        LiquidityParams calldata params,
        bytes calldata hookData
    ) external;
    
    // ============================================================================
    // STATE MANAGEMENT FUNCTIONS
    // ============================================================================
    
    /**
     * @notice Updates pool state for the current chain
     * @param poolKey The pool key
     * @param newState New pool state
     */
    function updatePoolState(bytes32 poolKey, PoolState calldata newState) external;
    
    /**
     * @notice Gets current pool state for the hook's chain
     * @param poolKey The pool key
     * @return Current pool state
     */
    function getPoolState(bytes32 poolKey) external view returns (PoolState memory);
    
    /**
     * @notice Gets global pool state across all chains
     * @param poolKey The pool key
     * @return totalLiquidity Total liquidity across all chains
     * @return averagePrice Weighted average price
     * @return imbalanceScore Maximum imbalance score
     * @return supportedChainsCount Number of supported chains
     * @return lastUpdateBlock Block number of last update
     */
    function getGlobalPoolState(bytes32 poolKey) external view returns (
        uint256 totalLiquidity,
        uint256 averagePrice,
        uint256 imbalanceScore,
        uint256 supportedChainsCount,
        uint256 lastUpdateBlock
    );
    
    /**
     * @notice Checks if rebalancing should be triggered
     * @param poolKey The pool key
     * @return Rebalancing trigger information
     */
    function checkRebalancingTrigger(bytes32 poolKey) external view returns (RebalancingTrigger memory);
    
    // ============================================================================
    // CONFIGURATION FUNCTIONS
    // ============================================================================
    
    /**
     * @notice Updates imbalance threshold
     * @param newThreshold New threshold value
     */
    function updateImbalanceThreshold(uint256 newThreshold) external;
    
    /**
     * @notice Updates optimization parameters
     * @param newParams New optimization parameters
     */
    function updateOptimizationParams(OptimizationConfig calldata newParams) external;
    
    /**
     * @notice Adds a supported chain
     * @param chainId Chain ID to add
     * @param isActive Whether the chain is active
     */
    function addSupportedChain(uint256 chainId, bool isActive) external;
    
    /**
     * @notice Removes a supported chain
     * @param chainId Chain ID to remove
     */
    function removeSupportedChain(uint256 chainId) external;
    
    // ============================================================================
    // SUPPORTING STRUCTS
    // ============================================================================
    
    
    struct LiquidityParams {
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        address recipient;
        uint256 deadline;
    }
    
    struct OptimizationConfig {
        uint256 maxFeeAdjustment;
        uint256 maxLiquidityBonus;
        uint256 maxPriceImpactReduction;
        bool enableGasOptimization;
    }
    
    // ============================================================================
    // EVENTS
    // ============================================================================
    
    event PoolStateUpdated(
        bytes32 indexed poolKey,
        uint256 indexed chainId,
        uint256 totalLiquidity,
        uint256 price,
        uint256 timestamp
    );
    
    event SwapOptimized(
        bytes32 indexed poolKey,
        address indexed user,
        int256 feeAdjustment,
        uint256 liquidityBonus,
        uint256 priceImpactReduction
    );
    
    event RebalancingTriggered(
        bytes32 indexed poolKey,
        uint256 indexed sourceChain,
        uint256 indexed targetChain,
        uint256 amount,
        uint256 urgency
    );
    
    event ConfigurationUpdated(
        string indexed parameter,
        uint256 oldValue,
        uint256 newValue
    );
}
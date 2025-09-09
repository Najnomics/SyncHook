// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title Constants
 * @author SyncHook Team
 * @notice Centralized constants for the SyncHook system
 * @dev Contains all system-wide constants including precision values, thresholds, and limits
 */
library Constants {
    // ============================================================================
    // PRECISION CONSTANTS
    // ============================================================================
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant PERCENTAGE_PRECISION = 1e6; // 6 decimal places for percentages
    uint256 public constant BASIS_POINTS = 10000; // For basis points calculations
    
    // ============================================================================
    // OPERATOR MANAGEMENT
    // ============================================================================
    
    uint256 public constant OPERATOR_STAKE_MINIMUM = 32 ether;
    uint256 public constant OPERATOR_STAKE_MAXIMUM = 1000 ether;
    uint256 public constant OPERATOR_REGISTRATION_FEE = 0.1 ether;
    uint256 public constant OPERATOR_DEREGISTRATION_DELAY = 7 days;
    
    // ============================================================================
    // SLASHING PARAMETERS
    // ============================================================================
    
    uint256 public constant SLASHING_PENALTY_RATE = 50000; // 5% in basis points
    uint256 public constant MAX_SLASHING_PENALTY = 10 ether;
    uint256 public constant SLASHING_COOLDOWN_PERIOD = 24 hours;
    
    // ============================================================================
    // TASK MANAGEMENT
    // ============================================================================
    
    uint256 public constant TASK_RESPONSE_WINDOW = 30 minutes;
    uint256 public constant TASK_CHALLENGE_WINDOW = 10 minutes;
    uint256 public constant MAX_TASK_RESPONSES_PER_BLOCK = 100;
    uint256 public constant TASK_FEE = 0.01 ether;
    
    // ============================================================================
    // REBALANCING PARAMETERS
    // ============================================================================
    
    uint256 public constant DEFAULT_IMBALANCE_THRESHOLD = 50000; // 5% in basis points
    uint256 public constant MAX_IMBALANCE_THRESHOLD = 200000; // 20% in basis points
    uint256 public constant MIN_REBALANCING_AMOUNT = 1000 * PRECISION;
    uint256 public constant MAX_REBALANCING_AMOUNT = 1000000 * PRECISION;
    uint256 public constant REBALANCING_FEE_RATE = 1000; // 0.1% in basis points
    uint256 public constant MAX_REBALANCING_FEE = 100 ether;
    
    // ============================================================================
    // PRICE AND LIQUIDITY VALIDATION
    // ============================================================================
    
    uint256 public constant DEFAULT_PRICE_DEVIATION = 100000; // 10% in basis points
    uint256 public constant MAX_PRICE_DEVIATION = 500000; // 50% in basis points
    uint256 public constant MIN_LIQUIDITY_THRESHOLD = 1000 * PRECISION;
    uint256 public constant MAX_LIQUIDITY_CHANGE_RATE = 200000; // 20% in basis points
    uint256 public constant PRICE_STALENESS_THRESHOLD = 5 minutes;
    
    // ============================================================================
    // CROSS-CHAIN PARAMETERS
    // ============================================================================
    
    uint256 public constant MIN_SUPPORTED_CHAINS = 2;
    uint256 public constant MAX_SUPPORTED_CHAINS = 10;
    uint256 public constant CROSS_CHAIN_MESSAGE_GAS_LIMIT = 1000000;
    uint256 public constant BRIDGE_CONFIRMATION_BLOCKS = 12;
    
    // ============================================================================
    // EMERGENCY CONTROLS
    // ============================================================================
    
    uint256 public constant EMERGENCY_PAUSE_DURATION = 24 hours;
    uint256 public constant GOVERNANCE_DELAY = 48 hours;
    uint256 public constant MAX_EMERGENCY_PAUSES = 3;
    
    // ============================================================================
    // AGGREGATION SETTINGS
    // ============================================================================
    
    uint256 public constant MIN_CONFIDENCE_THRESHOLD = 700000; // 70% in basis points
    uint256 public constant DEFAULT_CONFIDENCE_THRESHOLD = 800000; // 80% in basis points
    uint256 public constant MAX_STALE_TIME = 10 minutes;
    uint256 public constant MIN_VALIDATORS_FOR_CONSENSUS = 3;
    
    // ============================================================================
    // GAS OPTIMIZATION
    // ============================================================================
    
    uint256 public constant MAX_BATCH_SIZE = 50;
    uint256 public constant GAS_PRICE_THRESHOLD = 50 gwei;
    uint256 public constant MAX_GAS_PRICE = 200 gwei;
    
    // ============================================================================
    // CHAIN IDS (for reference)
    // ============================================================================
    
    uint256 public constant ETHEREUM_CHAIN_ID = 1;
    uint256 public constant POLYGON_CHAIN_ID = 137;
    uint256 public constant ARBITRUM_CHAIN_ID = 42161;
    uint256 public constant OPTIMISM_CHAIN_ID = 10;
    uint256 public constant BASE_CHAIN_ID = 8453;
}
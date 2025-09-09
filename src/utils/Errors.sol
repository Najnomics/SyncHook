// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title Errors
 * @author SyncHook Team
 * @notice Centralized error definitions for the SyncHook system
 * @dev Custom errors with descriptive parameters for better debugging and gas efficiency
 */
library Errors {
    // ============================================================================
    // GENERAL ERRORS
    // ============================================================================
    
    error InvalidAddress(address addr);
    error InvalidAmount(uint256 amount, uint256 min, uint256 max);
    error InvalidParameter(string param);
    error Unauthorized(address caller);
    error InsufficientBalance(uint256 available, uint256 required);
    error TransferFailed(address token, address to, uint256 amount);
    
    // ============================================================================
    // OPERATOR MANAGEMENT ERRORS
    // ============================================================================
    
    error OperatorNotRegistered(address operator);
    error OperatorAlreadyRegistered(address operator);
    error InvalidOperator(address operator);
    error InsufficientStake(uint256 current, uint256 required);
    error OperatorSlashed(address operator, uint256 amount);
    error InvalidStakeAmount(uint256 amount);
    
    // ============================================================================
    // TASK MANAGEMENT ERRORS
    // ============================================================================
    
    error TaskNotFound(uint32 taskIndex);
    error TaskExpired(uint256 deadline, uint256 currentTime);
    error TaskAlreadyResponded(uint32 taskIndex);
    error InvalidTaskResponse(uint32 taskIndex, string reason);
    error TaskResponseWindowClosed(uint32 taskIndex);
    error InvalidTaskHash(bytes32 expected, bytes32 actual);
    
    // ============================================================================
    // VALIDATION ERRORS
    // ============================================================================
    
    error ValidationFailed(string reason);
    error InvalidSignature(address signer, bytes signature);
    error StateValidationFailed(address validator, string reason);
    error InsufficientConfidence(uint256 confidence, uint256 required);
    error StaleData(uint256 timestamp, uint256 maxAge);
    error InvalidThreshold();
    
    // ============================================================================
    // REBALANCING ERRORS
    // ============================================================================
    
    error RebalancingInProgress();
    error RebalancingFailed(bytes32 requestId, string reason);
    error InsufficientLiquidity(uint256 available, uint256 required);
    error InvalidRebalancingAmount(uint256 amount);
    error BridgeNotConfigured(uint256 chainId);
    error CrossChainTransferFailed(uint256 sourceChain, uint256 targetChain);
    
    // ============================================================================
    // PRICE AND LIQUIDITY ERRORS
    // ============================================================================
    
    error PriceDeviationExceeded(uint256 deviation, uint256 maxAllowed);
    error LiquidityImbalanceExceeded(uint256 imbalance, uint256 maxAllowed);
    error InvalidPriceData(uint256 price);
    error PriceOracleFailure(address oracle);
    error InsufficientLiquidityDepth(uint256 depth);
    
    // ============================================================================
    // CROSS-CHAIN ERRORS
    // ============================================================================
    
    error UnsupportedChain(uint256 chainId);
    error CrossChainMessageFailed(uint256 chainId, bytes data);
    error InvalidChainConfiguration(uint256 chainId);
    error BridgeConnectionFailed(uint256 chainId);
    error MessageVerificationFailed(bytes32 messageHash);
    
    // ============================================================================
    // EMERGENCY AND GOVERNANCE ERRORS
    // ============================================================================
    
    error EmergencyPaused();
    error NotPaused();
    error GovernanceDelayNotMet(uint256 timeRemaining);
    error EmergencyPauseLimitReached();
    error InvalidGovernanceAction(bytes4 selector);
    
    // ============================================================================
    // AGGREGATION ERRORS
    // ============================================================================
    
    error InsufficientValidators(uint256 count, uint256 required);
    error ConsensusNotReached(uint256 votes, uint256 required);
    error InvalidAggregationConfig();
    error StateInconsistency(string reason);
    error MetricsCalculationFailed();
    
    // ============================================================================
    // SLASHING ERRORS
    // ============================================================================
    
    error SlashingCooldownActive(uint256 timeRemaining);
    error InvalidSlashingAmount(uint256 amount, uint256 maxAllowed);
    error SlashingFailed(address operator, string reason);
    error InsufficientSlashingEvidence();
    
    // ============================================================================
    // HOOK SPECIFIC ERRORS
    // ============================================================================
    
    error HookNotAuthorized();
    error InvalidHookData(bytes data);
    error SwapParameterOptimizationFailed();
    error PoolStateUpdateFailed(bytes32 poolId);
    error OptimizationThresholdNotMet();
    
    // ============================================================================
    // INTEGRATION ERRORS
    // ============================================================================
    
    error ProtocolIntegrationFailed(string protocol, string reason);
    error IncompatibleProtocolVersion(string protocol, string version);
    error ExternalCallFailed(address target, bytes data);
    error ProtocolNotSupported(string protocol);
}
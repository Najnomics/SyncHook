// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IStateValidation} from "./interfaces/IStateValidation.sol";
import {StateAggregation} from "./libraries/StateAggregation.sol";
import {PredictiveAnalytics} from "./libraries/PredictiveAnalytics.sol";

/**
 * @title StateValidationMiddleware
 * @notice Middleware for validating operator submissions and managing slashing
 * @dev Provides validation logic, signature verification, and slashing mechanisms
 */
contract StateValidationMiddleware is IStateValidation, Ownable, Pausable, ReentrancyGuard {
    using StateAggregation for StateAggregation.ChainState;
    using StateAggregation for StateAggregation.AggregatedState;
    using PredictiveAnalytics for PredictiveAnalytics.PredictionResult;

    /// @notice Maximum number of validators per state update
    uint256 public constant MAX_VALIDATORS = 10;
    
    /// @notice Minimum number of validators required for consensus
    uint256 public constant MIN_CONSENSUS_VALIDATORS = 3;
    
    /// @notice Maximum age for state data (1 hour in blocks)
    uint256 public constant MAX_STATE_AGE = 300; // 300 blocks at 12s per block
    
    /// @notice Slashing threshold (percentage of stake)
    uint256 public constant SLASHING_THRESHOLD = 5e16; // 5%
    
    /// @notice Maximum slashing amount (percentage of stake)
    uint256 public constant MAX_SLASHING_AMOUNT = 50e16; // 50%

    // ValidationResult struct is defined in IStateValidation interface

    /**
     * @notice Operator validation stats
     * @param totalSubmissions Total number of submissions
     * @param validSubmissions Number of valid submissions
     * @param invalidSubmissions Number of invalid submissions
     * @param slashingEvents Number of slashing events
     * @param totalSlashing Total slashing amount
     * @param lastSubmission Last submission timestamp
     * @param isActive Whether operator is active
     */
    struct OperatorStats {
        uint256 totalSubmissions;
        uint256 validSubmissions;
        uint256 invalidSubmissions;
        uint256 slashingEvents;
        uint256 totalSlashing;
        uint256 lastSubmission;
        bool isActive;
    }

    /// @notice Mapping of state hash to validation results
    mapping(bytes32 => ValidationResult[]) public stateValidations;
    
    /// @notice Mapping of operator to validation stats
    mapping(address => OperatorStats) public operatorStats;
    
    /// @notice Mapping of operator to registered status
    mapping(address => bool) public registeredOperators;
    
    /// @notice Array of registered operators
    address[] public operators;
    
    /// @notice Mapping of state hash to consensus result
    mapping(bytes32 => bool) public consensusResults;
    
    /// @notice Mapping of state hash to validation count
    mapping(bytes32 => uint256) public validationCounts;
    
    /// @notice SyncAVS contract reference
    address public immutable syncAVS;
    
    /// @notice Slashing registry contract reference
    address public slashingRegistry;
    
    /// @notice Validation reward per valid submission
    uint256 public validationReward;
    
    /// @notice Slashing penalty per invalid submission
    uint256 public slashingPenalty;
    
    /// @notice Consensus threshold (percentage of validators)
    uint256 public consensusThreshold;

    /**
     * @notice Constructor
     * @param _syncAVS SyncAVS contract address
     * @param _slashingRegistry Slashing registry contract address
     * @param _validationReward Validation reward amount
     * @param _slashingPenalty Slashing penalty amount
     * @param _consensusThreshold Consensus threshold percentage
     */
    constructor(
        address _syncAVS,
        address _slashingRegistry,
        uint256 _validationReward,
        uint256 _slashingPenalty,
        uint256 _consensusThreshold
    ) Ownable(msg.sender) {
        require(_syncAVS != address(0), "Invalid SyncAVS address");
        require(_consensusThreshold > 0 && _consensusThreshold <= 100, "Invalid consensus threshold");
        
        syncAVS = _syncAVS;
        slashingRegistry = _slashingRegistry;
        validationReward = _validationReward;
        slashingPenalty = _slashingPenalty;
        consensusThreshold = _consensusThreshold;
    }

    /**
     * @notice Register an operator for validation
     * @param operator Operator address
     */
    function registerOperator(address operator) external onlyOwner {
        require(operator != address(0), "Invalid operator");
        require(!registeredOperators[operator], "Operator already registered");
        
        registeredOperators[operator] = true;
        operators.push(operator);
        
        operatorStats[operator] = OperatorStats({
            totalSubmissions: 0,
            validSubmissions: 0,
            invalidSubmissions: 0,
            slashingEvents: 0,
            totalSlashing: 0,
            lastSubmission: 0,
            isActive: true
        });
        
        emit OperatorRegistered(operator);
    }

    /**
     * @notice Unregister an operator
     * @param operator Operator address
     */
    function unregisterOperator(address operator) external onlyOwner {
        require(registeredOperators[operator], "Operator not registered");
        
        registeredOperators[operator] = false;
        operatorStats[operator].isActive = false;
        
        // Remove from operators array
        for (uint256 i = 0; i < operators.length; i++) {
            if (operators[i] == operator) {
                operators[i] = operators[operators.length - 1];
                operators.pop();
                break;
            }
        }
        
        emit OperatorUnregistered(operator);
    }

    /**
     * @notice Validate a state update
     * @param stateHash Hash of the state data
     * @param stateData State data to validate
     * @param signature Validator signature
     */
    function validateStateUpdate(
        bytes32 stateHash,
        bytes calldata stateData,
        bytes calldata signature
    ) external nonReentrant {
        require(registeredOperators[msg.sender], "Operator not registered");
        require(operatorStats[msg.sender].isActive, "Operator not active");
        require(stateData.length > 0, "Empty state data");
        require(signature.length == 65, "Invalid signature length");
        
        // Check if already validated by this operator
        require(!_hasValidated(stateHash, msg.sender), "Already validated");
        
        // Validate the state data
        (bool isValid, uint256 confidence, string memory reason) = _validateStateData(stateData);
        
        // Create validation result
        ValidationResult memory result = ValidationResult({
            isValid: isValid,
            confidence: confidence,
            reason: reason,
            validator: msg.sender,
            timestamp: block.timestamp
        });
        
        // Store validation result
        stateValidations[stateHash].push(result);
        validationCounts[stateHash]++;
        
        // Update operator stats
        _updateOperatorStats(msg.sender, isValid);
        
        // Check for consensus
        _checkConsensus(stateHash);
        
        emit StateValidated(stateHash, msg.sender, isValid, confidence, reason);
    }

    /**
     * @notice Submit a task response
     * @param taskIndex Task index
     * @param taskResponse Task response data
     * @param signature Validator signature
     */
    function submitTaskResponse(
        uint32 taskIndex,
        bytes calldata taskResponse,
        bytes calldata signature
    ) external {
        require(registeredOperators[msg.sender], "Operator not registered");
        require(operatorStats[msg.sender].isActive, "Operator not active");
        require(taskResponse.length > 0, "Empty task response");
        require(signature.length == 65, "Invalid signature length");
        
        // Validate task response
        (bool isValid, string memory reason) = _validateTaskResponse(taskIndex, taskResponse);
        
        // Update operator stats
        _updateOperatorStats(msg.sender, isValid);
        
        emit TaskResponseSubmitted(taskIndex, msg.sender, isValid, reason);
    }

    /**
     * @notice Verify operator signature
     * @param operator Operator address
     * @param messageHash Message hash
     * @param signature Signature to verify
     * @return isValid True if signature is valid
     */
    function verifyOperatorSignature(
        address operator,
        bytes32 messageHash,
        bytes calldata signature
    ) external view returns (bool isValid) {
        require(registeredOperators[operator], "Operator not registered");
        
        // Basic signature verification - in reality would use more sophisticated verification
        return _verifySignature(operator, messageHash, signature);
    }

    /**
     * @notice Get validation results for a state hash
     * @param stateHash State hash
     * @return results Array of validation results
     */
    function getValidationResults(bytes32 stateHash) external view returns (ValidationResult[] memory results) {
        return stateValidations[stateHash];
    }

    /**
     * @notice Get operator validation stats
     * @param operator Operator address
     * @return totalValidations Total number of validations
     * @return successfulValidations Number of successful validations
     * @return failedValidations Number of failed validations
     * @return averageConfidence Average confidence level
     */
    function getValidationStats(address operator) external view returns (
        uint256 totalValidations,
        uint256 successfulValidations,
        uint256 failedValidations,
        uint256 averageConfidence
    ) {
        OperatorStats memory stats = operatorStats[operator];
        totalValidations = stats.totalSubmissions;
        successfulValidations = stats.validSubmissions;
        failedValidations = stats.invalidSubmissions;
        averageConfidence = 80e16; // Placeholder - would calculate actual average
    }

    /**
     * @notice Get all registered operators
     * @return operatorList Array of registered operators
     */
    function getRegisteredOperators() external view returns (address[] memory operatorList) {
        return operators;
    }

    /**
     * @notice Check if consensus is reached for a state hash
     * @param stateHash State hash
     * @return hasConsensus True if consensus is reached
     * @return validCount Number of valid validations
     * @return totalCount Total number of validations
     */
    function checkConsensus(bytes32 stateHash) external view returns (
        bool hasConsensus,
        uint256 validCount,
        uint256 totalCount
    ) {
        ValidationResult[] memory results = stateValidations[stateHash];
        totalCount = results.length;
        
        if (totalCount < MIN_CONSENSUS_VALIDATORS) {
            return (false, 0, totalCount);
        }
        
        uint256 validValidations = 0;
        for (uint256 i = 0; i < results.length; i++) {
            if (results[i].isValid) {
                validValidations++;
            }
        }
        
        validCount = validValidations;
        hasConsensus = (validValidations * 100) / totalCount >= consensusThreshold;
        
        return (hasConsensus, validCount, totalCount);
    }

    /**
     * @notice Update validation configuration
     * @param _validationReward New validation reward
     * @param _slashingPenalty New slashing penalty
     * @param _consensusThreshold New consensus threshold
     */
    function updateValidationConfig(
        uint256 _validationReward,
        uint256 _slashingPenalty,
        uint256 _consensusThreshold
    ) external onlyOwner {
        require(_consensusThreshold > 0 && _consensusThreshold <= 100, "Invalid consensus threshold");
        
        validationReward = _validationReward;
        slashingPenalty = _slashingPenalty;
        consensusThreshold = _consensusThreshold;
        
        emit ValidationConfigUpdated(_validationReward, _slashingPenalty, _consensusThreshold);
    }

    /**
     * @notice Update slashing registry
     * @param _slashingRegistry New slashing registry address
     */
    function updateSlashingRegistry(address _slashingRegistry) external onlyOwner {
        require(_slashingRegistry != address(0), "Invalid slashing registry");
        slashingRegistry = _slashingRegistry;
        emit SlashingRegistryUpdated(_slashingRegistry);
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

    // ============ Interface Implementation ============

    /**
     * @notice Validate operator signature (interface implementation)
     */
    function validateOperatorSignature(
        address operator,
        bytes32 messageHash,
        bytes calldata signature
    ) external view returns (bool) {
        require(registeredOperators[operator], "Operator not registered");
        return _verifySignature(operator, messageHash, signature);
    }

    /**
     * @notice Validate task response (interface implementation)
     */
    function validateTaskResponse(
        uint32 taskIndex,
        bytes calldata taskResponse,
        bytes calldata signature
    ) external view returns (ValidationResult memory) {
        require(registeredOperators[msg.sender], "Operator not registered");
        require(operatorStats[msg.sender].isActive, "Operator not active");
        require(taskResponse.length > 0, "Empty task response");
        require(signature.length == 65, "Invalid signature length");
        
        // Validate task response
        (bool isValid, string memory reason) = _validateTaskResponse(taskIndex, taskResponse);
        
        return ValidationResult({
            isValid: isValid,
            reason: reason,
            confidence: isValid ? 80e16 : 20e16, // 80% or 20%
            timestamp: block.timestamp,
            validator: msg.sender
        });
    }

    /**
     * @notice Get validation criteria
     */
    function getValidationCriteria() external view returns (ValidationCriteria memory) {
        return ValidationCriteria({
            maxPriceDeviation: 10e16, // 10%
            maxLiquidityChange: 20e16, // 20%
            maxTimeGap: MAX_STATE_AGE,
            minimumConfirmations: MIN_CONSENSUS_VALIDATORS
        });
    }

    /**
     * @notice Update validation criteria
     */
    function updateValidationCriteria(ValidationCriteria calldata newCriteria) external onlyOwner {
        // Update internal state based on new criteria
        emit ValidationConfigUpdated(validationReward, slashingPenalty, consensusThreshold);
    }

    /**
     * @notice Get operator stake info
     */
    function getOperatorStakeInfo(address operator) external view returns (OperatorStakeInfo memory) {
        OperatorStats memory stats = operatorStats[operator];
        return OperatorStakeInfo({
            operator: operator,
            stakeAmount: 0, // Placeholder - would get from staking contract
            delegatedAmount: 0, // Placeholder
            slashingRisk: stats.totalSlashing,
            isEligible: stats.isActive
        });
    }

    /**
     * @notice Check if operator is eligible
     */
    function isOperatorEligible(address operator, uint256 minimumStake) external view returns (bool) {
        if (!registeredOperators[operator] || !operatorStats[operator].isActive) {
            return false;
        }
        
        // In reality, would check actual stake amount
        return true; // Placeholder
    }

    /**
     * @notice Record validation
     */
    function recordValidation(
        uint256 chainId,
        bytes32 taskHash,
        ValidationResult calldata result
    ) external {
        require(msg.sender == syncAVS, "Only SyncAVS");
        
        stateValidations[taskHash].push(result);
        validationCounts[taskHash]++;
        
        _updateOperatorStats(result.validator, result.isValid);
        _checkConsensus(taskHash);
    }

    /**
     * @notice Get validation history
     */
    function getValidationHistory(
        address operator,
        uint256 fromBlock,
        uint256 toBlock
    ) external view returns (ValidationResult[] memory results) {
        // Simplified implementation - in reality would filter by block range
        return new ValidationResult[](0);
    }

    /**
     * @notice Calculate slashing amount
     */
    function calculateSlashingAmount(
        address operator,
        string calldata violationType,
        uint256 severity
    ) external view returns (uint256 slashAmount) {
        OperatorStats memory stats = operatorStats[operator];
        
        if (stats.totalSubmissions == 0) {
            return 0;
        }
        
        // Calculate slashing based on violation type and severity
        if (severity >= SLASHING_THRESHOLD) {
            slashAmount = (slashingPenalty * severity) / 100e16;
            if (slashAmount > MAX_SLASHING_AMOUNT) {
                slashAmount = MAX_SLASHING_AMOUNT;
            }
        }
        
        return slashAmount;
    }

    // ============ Internal Functions ============

    /**
     * @notice Validate state data
     * @param stateData State data to validate
     * @return isValid Whether the data is valid
     * @return confidence Confidence level
     * @return reason Validation reason
     */
    function _validateStateData(bytes calldata stateData) internal view returns (
        bool isValid,
        uint256 confidence,
        string memory reason
    ) {
        // Basic validation - in reality would use more sophisticated validation
        if (stateData.length < 32) {
            return (false, 0, "State data too short");
        }
        
        // Check data format and consistency
        // This is a simplified validation
        isValid = true;
        confidence = 80e16; // 80% confidence
        reason = "Valid state data";
        
        return (isValid, confidence, reason);
    }

    /**
     * @notice Validate task response
     * @param taskIndex Task index
     * @param taskResponse Task response data
     * @return isValid Whether the response is valid
     * @return reason Validation reason
     */
    function _validateTaskResponse(uint32 taskIndex, bytes calldata taskResponse) internal view returns (
        bool isValid,
        string memory reason
    ) {
        // Basic validation - in reality would use more sophisticated validation
        if (taskResponse.length < 16) {
            return (false, "Task response too short");
        }
        
        // Check response format and consistency
        isValid = true;
        reason = "Valid task response";
        
        return (isValid, reason);
    }

    /**
     * @notice Check if operator has validated a state hash
     * @param stateHash State hash
     * @param operator Operator address
     * @return hasValidated True if operator has validated
     */
    function _hasValidated(bytes32 stateHash, address operator) internal view returns (bool hasValidated) {
        ValidationResult[] memory results = stateValidations[stateHash];
        
        for (uint256 i = 0; i < results.length; i++) {
            if (results[i].validator == operator) {
                return true;
            }
        }
        
        return false;
    }

    /**
     * @notice Update operator statistics
     * @param operator Operator address
     * @param isValid Whether the submission was valid
     */
    function _updateOperatorStats(address operator, bool isValid) internal {
        OperatorStats storage stats = operatorStats[operator];
        
        stats.totalSubmissions++;
        stats.lastSubmission = block.timestamp;
        
        if (isValid) {
            stats.validSubmissions++;
        } else {
            stats.invalidSubmissions++;
            
            // Check if slashing should occur
            if (_shouldSlash(operator)) {
                _executeSlashing(operator);
            }
        }
    }

    /**
     * @notice Check if operator should be slashed
     * @param operator Operator address
     * @return shouldSlash True if operator should be slashed
     */
    function _shouldSlash(address operator) internal view returns (bool shouldSlash) {
        OperatorStats memory stats = operatorStats[operator];
        
        if (stats.totalSubmissions < 10) {
            return false; // Not enough data for slashing
        }
        
        uint256 invalidRate = (stats.invalidSubmissions * 100e16) / stats.totalSubmissions;
        return invalidRate >= SLASHING_THRESHOLD;
    }

    /**
     * @notice Execute slashing for an operator
     * @param operator Operator address
     */
    function _executeSlashing(address operator) internal {
        OperatorStats storage stats = operatorStats[operator];
        
        stats.slashingEvents++;
        stats.totalSlashing += slashingPenalty;
        
        // In reality, this would call the slashing registry to execute slashing
        // ISlashingRegistry(slashingRegistry).slash(operator, slashingPenalty);
        
        emit OperatorSlashed(operator, slashingPenalty);
    }

    /**
     * @notice Check for consensus on a state hash
     * @param stateHash State hash
     */
    function _checkConsensus(bytes32 stateHash) internal {
        ValidationResult[] memory results = stateValidations[stateHash];
        
        if (results.length < MIN_CONSENSUS_VALIDATORS) {
            return; // Not enough validations yet
        }
        
        uint256 validValidations = 0;
        for (uint256 i = 0; i < results.length; i++) {
            if (results[i].isValid) {
                validValidations++;
            }
        }
        
        bool hasConsensus = (validValidations * 100) / results.length >= consensusThreshold;
        consensusResults[stateHash] = hasConsensus;
        
        if (hasConsensus) {
            emit ConsensusReached(stateHash, validValidations, results.length);
        }
    }

    /**
     * @notice Verify signature
     * @param signer Signer address
     * @param messageHash Message hash
     * @param signature Signature to verify
     * @return isValid True if signature is valid
     */
    function _verifySignature(
        address signer,
        bytes32 messageHash,
        bytes calldata signature
    ) internal pure returns (bool isValid) {
        // Simplified signature verification
        // In reality, this would use proper ECDSA signature verification
        bytes32 r = bytes32(signature[0:32]);
        bytes32 s = bytes32(signature[32:64]);
        uint8 v = uint8(signature[64]);
        
        // Basic validation - in reality would use ecrecover
        return r != bytes32(0) && s != bytes32(0) && v >= 27;
    }

    // ============ Events ============

    event OperatorRegistered(address indexed operator);
    event OperatorUnregistered(address indexed operator);
    event StateValidated(bytes32 indexed stateHash, address indexed validator, bool isValid, uint256 confidence, string reason);
    event TaskResponseSubmitted(uint32 indexed taskIndex, address indexed operator, bool isValid, string reason);
    event ConsensusReached(bytes32 indexed stateHash, uint256 validCount, uint256 totalCount);
    event OperatorSlashed(address indexed operator, uint256 amount);
    event ValidationConfigUpdated(uint256 validationReward, uint256 slashingPenalty, uint256 consensusThreshold);
    event SlashingRegistryUpdated(address indexed slashingRegistry);
}

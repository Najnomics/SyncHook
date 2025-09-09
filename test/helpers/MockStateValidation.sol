// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title MockStateValidation
 * @author SyncHook Team
 * @notice Mock implementation of state validation for testing purposes
 * @dev Provides controllable validation responses for comprehensive testing
 */

import {IStateValidation} from "../../src/avs/interfaces/IStateValidation.sol";
import {Constants} from "../../src/utils/Constants.sol";

contract MockStateValidation is IStateValidation {
    /*//////////////////////////////////////////////////////////////
                            MOCK STATE
    //////////////////////////////////////////////////////////////*/
    
    ValidationResult private _mockResult;
    ValidationCriteria private _criteria;
    mapping(address => OperatorStakeInfo) private _stakeInfo;
    
    bool public shouldFail;
    
    /*//////////////////////////////////////////////////////////////
                        CONFIGURATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    constructor() {
        _criteria = ValidationCriteria({
            maxPriceDeviation: Constants.DEFAULT_PRICE_DEVIATION,
            maxLiquidityChange: Constants.DEFAULT_IMBALANCE_THRESHOLD,
            maxTimeGap: 300,
            minimumConfirmations: 2
        });
        
        _mockResult = ValidationResult({
            isValid: true,
            reason: "Mock validation passed",
            confidence: 9000,
            timestamp: block.timestamp,
            validator: address(this)
        });
    }
    
    /// @notice Set the validation result for testing
    function setValidationResult(bool isValid, string memory reason, uint256 confidence) external {
        _mockResult = ValidationResult({
            isValid: isValid,
            reason: reason,
            confidence: confidence,
            timestamp: block.timestamp,
            validator: address(this)
        });
    }
    
    /// @notice Set the validation result with custom validator address for testing
    function setValidationResultWithValidator(
        bool isValid, 
        string memory reason, 
        uint256 confidence,
        address validator
    ) external {
        _mockResult = ValidationResult({
            isValid: isValid,
            reason: reason,
            confidence: confidence,
            timestamp: block.timestamp,
            validator: validator
        });
    }
    
    /// @notice Configure whether operations should fail
    function setShouldFail(bool _shouldFail) external {
        shouldFail = _shouldFail;
    }
    
    /// @notice Set mock stake info for an operator
    function setOperatorStakeInfo(
        address operator,
        uint256 stakeAmount,
        uint256 delegatedAmount,
        bool isEligible
    ) external {
        _stakeInfo[operator] = OperatorStakeInfo({
            operator: operator,
            stakeAmount: stakeAmount,
            delegatedAmount: delegatedAmount,
            slashingRisk: 0,
            isEligible: isEligible
        });
    }
    
    /*//////////////////////////////////////////////////////////////
                        MOCK IMPLEMENTATIONS
    //////////////////////////////////////////////////////////////*/
    
    function validateTaskResponse(
        uint32 taskIndex,
        bytes calldata taskResponse,
        bytes calldata signature
    ) external view override returns (ValidationResult memory) {
        if (shouldFail) {
            revert("Mock validation failure");
        }
        
        return _mockResult;
    }
    
    function validateOperatorSignature(
        address operator,
        bytes32 messageHash,
        bytes calldata signature
    ) external view override returns (bool) {
        if (shouldFail) {
            return false;
        }
        
        // Simple validation - signature must be correct length
        return signature.length == 65;
    }
    
    function getValidationCriteria() external view override returns (ValidationCriteria memory) {
        return _criteria;
    }
    
    function updateValidationCriteria(ValidationCriteria calldata newCriteria) external override {
        if (shouldFail) {
            revert("Mock criteria update failure");
        }
        
        _criteria = newCriteria;
    }
    
    function getOperatorStakeInfo(address operator)
        external
        view
        override
        returns (OperatorStakeInfo memory)
    {
        OperatorStakeInfo memory info = _stakeInfo[operator];
        
        // Return default if not set
        if (info.operator == address(0)) {
            return OperatorStakeInfo({
                operator: operator,
                stakeAmount: Constants.OPERATOR_STAKE_MINIMUM,
                delegatedAmount: 0,
                slashingRisk: 0,
                isEligible: true
            });
        }
        
        return info;
    }
    
    function isOperatorEligible(address operator, uint256 minimumStake)
        external
        view
        override
        returns (bool)
    {
        if (shouldFail) {
            return false;
        }
        
        OperatorStakeInfo memory info = this.getOperatorStakeInfo(operator);
        return info.isEligible && info.stakeAmount >= minimumStake;
    }
    
    function calculateSlashingAmount(
        address operator,
        string calldata violationType,
        uint256 severity
    ) external view override returns (uint256 slashAmount) {
        if (shouldFail) {
            return 0;
        }
        
        OperatorStakeInfo memory info = this.getOperatorStakeInfo(operator);
        
        // Simple calculation based on severity
        uint256 baseSlash = (info.stakeAmount * severity) / 100;
        
        // Apply violation type multiplier
        if (keccak256(bytes(violationType)) == keccak256(bytes("INVALID_STATE"))) {
            baseSlash = (baseSlash * 150) / 100; // 1.5x for invalid state
        } else if (keccak256(bytes(violationType)) == keccak256(bytes("LATE_RESPONSE"))) {
            baseSlash = (baseSlash * 50) / 100; // 0.5x for late response
        }
        
        return baseSlash;
    }
    
    function recordValidation(
        uint256 chainId,
        bytes32 taskHash,
        ValidationResult calldata result
    ) external override {
        if (shouldFail) {
            revert("Mock record validation failure");
        }
        
        // Mock implementation - just emit event
        emit StateValidated(chainId, bytes32(0), result.validator, result);
    }
    
    function getValidationHistory(
        address operator,
        uint256 fromBlock,
        uint256 toBlock
    ) external view override returns (ValidationResult[] memory) {
        if (shouldFail) {
            return new ValidationResult[](0);
        }
        
        // Return mock history with single entry
        ValidationResult[] memory history = new ValidationResult[](1);
        history[0] = _mockResult;
        return history;
    }
    
    function getValidationStats(address operator)
        external
        view
        override
        returns (
            uint256 totalValidations,
            uint256 successfulValidations,
            uint256 failedValidations,
            uint256 averageConfidence
        )
    {
        if (shouldFail) {
            return (0, 0, 0, 0);
        }
        
        // Return mock stats
        return (100, 95, 5, 8500);
    }
}
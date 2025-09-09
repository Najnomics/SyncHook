// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IStateValidation
 * @author SyncHook Team
 * @notice Interface for state validation functionality
 */
interface IStateValidation {
    struct ValidationResult {
        bool isValid;
        string reason;
        uint256 confidence;
        uint256 timestamp;
        address validator;
    }
    
    struct ValidationCriteria {
        uint256 maxPriceDeviation;
        uint256 maxLiquidityChange;
        uint256 maxTimeGap;
        uint256 minimumConfirmations;
    }
    
    struct OperatorStakeInfo {
        address operator;
        uint256 stakeAmount;
        uint256 delegatedAmount;
        uint256 slashingRisk;
        bool isEligible;
    }
    
    // Validation functions
    function validateTaskResponse(
        uint32 taskIndex,
        bytes calldata taskResponse,
        bytes calldata signature
    ) external view returns (ValidationResult memory);
    
    function validateOperatorSignature(
        address operator,
        bytes32 messageHash,
        bytes calldata signature
    ) external view returns (bool);
    
    // Configuration
    function getValidationCriteria() external view returns (ValidationCriteria memory);
    function updateValidationCriteria(ValidationCriteria calldata newCriteria) external;
    
    // Operator management
    function getOperatorStakeInfo(address operator) external view returns (OperatorStakeInfo memory);
    function isOperatorEligible(address operator, uint256 minimumStake) external view returns (bool);
    
    // Slashing
    function calculateSlashingAmount(
        address operator,
        string calldata violationType,
        uint256 severity
    ) external view returns (uint256 slashAmount);
    
    // History and analytics
    function recordValidation(
        uint256 chainId,
        bytes32 taskHash,
        ValidationResult calldata result
    ) external;
    
    function getValidationHistory(
        address operator,
        uint256 fromBlock,
        uint256 toBlock
    ) external view returns (ValidationResult[] memory);
    
    function getValidationStats(address operator)
        external
        view
        returns (
            uint256 totalValidations,
            uint256 successfulValidations,
            uint256 failedValidations,
            uint256 averageConfidence
        );
    
    // Events
    event StateValidated(
        uint256 indexed chainId,
        bytes32 indexed poolId,
        address indexed validator,
        ValidationResult result
    );
    
    event ValidationCriteriaUpdated(
        ValidationCriteria oldCriteria,
        ValidationCriteria newCriteria
    );
    
    event OperatorSlashingCalculated(
        address indexed operator,
        string violationType,
        uint256 severity,
        uint256 slashAmount
    );
}
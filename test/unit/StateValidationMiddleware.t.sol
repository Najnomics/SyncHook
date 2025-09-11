// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {StateValidationMiddleware} from "../../src/avs/StateValidationMiddleware.sol";
import {IStateValidation} from "../../src/avs/interfaces/IStateValidation.sol";

contract StateValidationMiddlewareTest is Test {
    StateValidationMiddleware public validation;
    
    address public owner = address(0x1);
    address public operator = address(0x2);
    address public user = address(0x3);
    
    function setUp() public {
        validation = new StateValidationMiddleware(
            address(0x1000), // syncAVS
            address(0x2000), // slashingRegistry
            0.01e18, // validationReward
            0.1e18,  // slashingPenalty
            75       // consensusThreshold
        );
    }
    
    function test_Deployment() public {
        assertTrue(address(validation) != address(0));
        assertEq(validation.validationReward(), 0.01e18);
        assertEq(validation.slashingPenalty(), 0.1e18);
        assertEq(validation.consensusThreshold(), 75);
    }
    
    function test_SubmitTaskResponse() public {
        validation.submitTaskResponse(
            1, // taskIndex
            "response", // taskResponse
            "" // signature
        );
        // Should not revert
    }
    
    function test_ValidateOperatorSignature() public {
        bool isValid = validation.validateOperatorSignature(
            operator,
            bytes32(0), // messageHash
            "" // signature
        );
        assertFalse(isValid); // Should be false for unregistered operator
    }
    
    function test_GetValidationHistoryInitial() public {
        IStateValidation.ValidationResult[] memory results = validation.getValidationHistory(operator, 0, 10);
        assertEq(results.length, 0); // Should be empty initially
    }
    
    function test_GetValidationStats() public {
        (
            uint256 totalValidations,
            uint256 successfulValidations,
            uint256 failedValidations,
            uint256 averageConfidence
        ) = validation.getValidationStats(operator);
        
        assertEq(totalValidations, 0);
        assertEq(successfulValidations, 0);
        assertEq(failedValidations, 0);
        assertEq(averageConfidence, 80e16); // Default value
    }
    
    function test_ValidateTaskResponse() public {
        IStateValidation.ValidationResult memory result = validation.validateTaskResponse(
            1, // taskIndex
            "response", // taskResponse
            "" // signature
        );
        
        assertTrue(result.isValid);
        assertEq(result.confidence, 80e16); // Default confidence
    }
    
    function test_GetValidationCriteria() public {
        IStateValidation.ValidationCriteria memory criteria = validation.getValidationCriteria();
        assertEq(criteria.maxPriceDeviation, 0.05e18); // 5%
        assertEq(criteria.maxLiquidityChange, 0.1e18); // 10%
        assertEq(criteria.maxTimeGap, 300); // 5 minutes
        assertEq(criteria.minimumConfirmations, 3);
    }
    
    function test_UpdateValidationCriteria() public {
        IStateValidation.ValidationCriteria memory newCriteria = IStateValidation.ValidationCriteria({
            maxPriceDeviation: 0.1e18, // 10%
            maxLiquidityChange: 0.2e18, // 20%
            maxTimeGap: 600, // 10 minutes
            minimumConfirmations: 5
        });
        
        validation.updateValidationCriteria(newCriteria);
        
        IStateValidation.ValidationCriteria memory criteria = validation.getValidationCriteria();
        assertEq(criteria.maxPriceDeviation, 0.1e18);
        assertEq(criteria.maxLiquidityChange, 0.2e18);
        assertEq(criteria.maxTimeGap, 600);
        assertEq(criteria.minimumConfirmations, 5);
    }
    
    function test_GetOperatorStakeInfo() public {
        IStateValidation.OperatorStakeInfo memory stakeInfo = validation.getOperatorStakeInfo(operator);
        assertEq(stakeInfo.stakeAmount, 0);
        assertEq(stakeInfo.delegatedAmount, 0);
        assertEq(stakeInfo.slashingRisk, 0);
        assertFalse(stakeInfo.isEligible);
    }
    
    function test_IsOperatorEligible() public {
        bool isEligible = validation.isOperatorEligible(operator, 1e18);
        assertFalse(isEligible); // Should be false for unregistered operator
    }
    
    function test_RecordValidation() public {
        IStateValidation.ValidationResult memory result = IStateValidation.ValidationResult({
            isValid: true,
            reason: "test",
            confidence: 90e16,
            timestamp: block.timestamp,
            validator: operator
        });
        
        validation.recordValidation(
            1, // chainId
            bytes32(0), // taskHash
            result
        );
        // Should not revert
    }
    
    function test_GetValidationHistory() public {
        IStateValidation.ValidationResult[] memory history = validation.getValidationHistory(
            operator,
            0, // fromBlock
            1000 // toBlock
        );
        assertEq(history.length, 0); // Should be empty initially
    }
    
    function test_CalculateSlashingAmount() public {
        uint256 slashingAmount = validation.calculateSlashingAmount(
            operator, // operator
            "price_manipulation", // violationType
            5 // severity
        );
        assertTrue(slashingAmount > 0);
    }
    
    function test_OnlyOwner() public {
        IStateValidation.ValidationCriteria memory newCriteria = IStateValidation.ValidationCriteria({
            maxPriceDeviation: 0.1e18,
            maxLiquidityChange: 0.2e18,
            maxTimeGap: 600,
            minimumConfirmations: 5
        });
        
        vm.prank(user);
        vm.expectRevert();
        validation.updateValidationCriteria(newCriteria);
    }
    
    function test_OnlyRegisteredOperator() public {
        vm.prank(user);
        vm.expectRevert();
        validation.submitTaskResponse(1, "response", "");
    }
    
    function test_InvalidTaskIndex() public {
        vm.expectRevert();
        validation.getValidationHistory(address(0), 0, 10); // Invalid operator
    }
}

package state

import (
	"context"
	"crypto/ecdsa"
	"crypto/sha256"
	"fmt"
	"math/big"
	"time"

	"github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/ethereum/go-ethereum/common"
	"github.com/synchook/operator/pkg/utils"
	"github.com/ethereum/go-ethereum/crypto"
)

type Validator struct {
	logger logging.Logger
}

type ValidationResult struct {
	IsValid    bool    `json:"isValid"`
	Confidence float64 `json:"confidence"`
	Reason     string  `json:"reason"`
	Timestamp  uint64  `json:"timestamp"`
}

type ValidationCriteria struct {
	MaxPriceDeviation    *big.Int `json:"maxPriceDeviation"`
	MaxLiquidityChange   *big.Int `json:"maxLiquidityChange"`
	MaxTimeGap          uint64   `json:"maxTimeGap"`
	MinimumConfirmations uint32   `json:"minimumConfirmations"`
}

func NewValidator(logger logging.Logger) *Validator {
	return &Validator{
		logger: logger,
	}
}

func (v *Validator) ValidatePoolState(
	ctx context.Context,
	poolState *PoolState,
	globalState *GlobalPoolState,
	criteria *ValidationCriteria,
) (*ValidationResult, error) {
	v.logger.Debug("Validating pool state",
		"chainID", poolState.ChainID,
		"liquidity", poolState.TotalLiquidity.String(),
		"price", poolState.Price.String(),
	)

	result := &ValidationResult{
		IsValid:   true,
		Timestamp: uint64(time.Now().Unix()),
	}

	// Validate price deviation
	if err := v.validatePriceDeviation(poolState, globalState, criteria, result); err != nil {
		return result, err
	}

	// Validate liquidity change
	if err := v.validateLiquidityChange(poolState, globalState, criteria, result); err != nil {
		return result, err
	}

	// Validate timestamp
	if err := v.validateTimestamp(poolState, criteria, result); err != nil {
		return result, err
	}

	// Calculate confidence score
	v.calculateConfidence(poolState, globalState, result)

	v.logger.Info("Pool state validation completed",
		"chainID", poolState.ChainID,
		"isValid", result.IsValid,
		"confidence", result.Confidence,
		"reason", result.Reason,
	)

	return result, nil
}

func (v *Validator) ValidateOperatorSignature(
	ctx context.Context,
	operatorAddr common.Address,
	messageHash common.Hash,
	signature []byte,
) (*ValidationResult, error) {
	v.logger.Debug("Validating operator signature",
		"operator", operatorAddr.Hex(),
		"messageHash", messageHash.Hex(),
		"signatureLength", len(signature),
	)

	result := &ValidationResult{
		IsValid:   false,
		Timestamp: uint64(time.Now().Unix()),
	}

	// Recover public key from signature
	pubKey, err := crypto.SigToPub(messageHash.Bytes(), signature)
	if err != nil {
		result.Reason = "Failed to recover public key from signature"
		return result, nil
	}

	// Get address from public key
	recoveredAddr := crypto.PubkeyToAddress(*pubKey)

	// Check if recovered address matches operator address
	if recoveredAddr != operatorAddr {
		result.Reason = "Signature does not match operator address"
		return result, nil
	}

	// Verify signature
	if !crypto.VerifySignature(crypto.CompressPubkey(pubKey), messageHash.Bytes(), signature[:64]) {
		result.Reason = "Signature verification failed"
		return result, nil
	}

	result.IsValid = true
	result.Confidence = 1.0
	result.Reason = "Signature validation successful"

	v.logger.Info("Operator signature validation completed",
		"operator", operatorAddr.Hex(),
		"isValid", result.IsValid,
		"confidence", result.Confidence,
	)

	return result, nil
}

func (v *Validator) ValidateTaskResponse(
	ctx context.Context,
	taskIndex uint32,
	response []byte,
	signature []byte,
	operatorAddr common.Address,
) (*ValidationResult, error) {
	v.logger.Debug("Validating task response",
		"taskIndex", taskIndex,
		"responseLength", len(response),
		"operator", operatorAddr.Hex(),
	)

	result := &ValidationResult{
		IsValid:   false,
		Timestamp: uint64(time.Now().Unix()),
	}

	// Create message hash from task index and response
	messageHash := v.createTaskResponseHash(taskIndex, response)

	// Validate signature
	sigResult, err := v.ValidateOperatorSignature(ctx, operatorAddr, messageHash, signature)
	if err != nil {
		return result, fmt.Errorf("failed to validate signature: %w", err)
	}

	if !sigResult.IsValid {
		result.Reason = "Invalid signature for task response"
		return result, nil
	}

	// Validate response format
	if err := v.validateResponseFormat(response); err != nil {
		result.Reason = fmt.Sprintf("Invalid response format: %v", err)
		return result, nil
	}

	result.IsValid = true
	result.Confidence = sigResult.Confidence
	result.Reason = "Task response validation successful"

	v.logger.Info("Task response validation completed",
		"taskIndex", taskIndex,
		"isValid", result.IsValid,
		"confidence", result.Confidence,
	)

	return result, nil
}

func (v *Validator) validatePriceDeviation(
	poolState *PoolState,
	globalState *GlobalPoolState,
	criteria *ValidationCriteria,
	result *ValidationResult,
) error {
	if globalState.AveragePrice.Cmp(big.NewInt(0)) == 0 {
		// No global price to compare against
		return nil
	}

	// Calculate price deviation
	priceDiff := new(big.Int).Sub(poolState.Price, globalState.AveragePrice)
	if priceDiff.Sign() < 0 {
		priceDiff.Neg(priceDiff)
	}

	// Check if deviation exceeds threshold
	if priceDiff.Cmp(criteria.MaxPriceDeviation) > 0 {
		result.IsValid = false
		result.Reason = fmt.Sprintf("Price deviation too high: %s > %s",
			priceDiff.String(), criteria.MaxPriceDeviation.String())
		return fmt.Errorf("price deviation validation failed")
	}

	return nil
}

func (v *Validator) validateLiquidityChange(
	poolState *PoolState,
	globalState *GlobalPoolState,
	criteria *ValidationCriteria,
	result *ValidationResult,
) error {
	// Get previous state for this chain
	prevState, exists := globalState.ChainStates[poolState.ChainID]
	if !exists {
		// No previous state to compare against
		return nil
	}

	// Calculate liquidity change
	liquidityChange := new(big.Int).Sub(poolState.TotalLiquidity, prevState.TotalLiquidity)
	if liquidityChange.Sign() < 0 {
		liquidityChange.Neg(liquidityChange)
	}

	// Check if change exceeds threshold
	if liquidityChange.Cmp(criteria.MaxLiquidityChange) > 0 {
		result.IsValid = false
		result.Reason = fmt.Sprintf("Liquidity change too high: %s > %s",
			liquidityChange.String(), criteria.MaxLiquidityChange.String())
		return fmt.Errorf("liquidity change validation failed")
	}

	return nil
}

func (v *Validator) validateTimestamp(
	poolState *PoolState,
	criteria *ValidationCriteria,
	result *ValidationResult,
) error {
	currentTime := uint64(time.Now().Unix())
	timeDiff := currentTime - poolState.Timestamp

	if timeDiff > criteria.MaxTimeGap {
		result.IsValid = false
		result.Reason = fmt.Sprintf("Timestamp too old: %d seconds > %d seconds",
			timeDiff, criteria.MaxTimeGap)
		return fmt.Errorf("timestamp validation failed")
	}

	return nil
}

func (v *Validator) calculateConfidence(
	poolState *PoolState,
	globalState *GlobalPoolState,
	result *ValidationResult,
) {
	confidence := 1.0

	// Reduce confidence based on price deviation
	if globalState.AveragePrice.Cmp(big.NewInt(0)) != 0 {
		priceDiff := new(big.Int).Sub(poolState.Price, globalState.AveragePrice)
		if priceDiff.Sign() < 0 {
			priceDiff.Neg(priceDiff)
		}

		// Calculate deviation percentage
		deviationPercent := new(big.Int).Mul(priceDiff, big.NewInt(100))
		deviationPercent.Div(deviationPercent, globalState.AveragePrice)

		// Reduce confidence based on deviation
		if deviationPercent.Cmp(big.NewInt(1)) > 0 {
			confidence *= 0.9
		}
		if deviationPercent.Cmp(big.NewInt(5)) > 0 {
			confidence *= 0.8
		}
		if deviationPercent.Cmp(big.NewInt(10)) > 0 {
			confidence *= 0.6
		}
	}

	// Reduce confidence based on timestamp age
	currentTime := uint64(time.Now().Unix())
	age := currentTime - poolState.Timestamp
	if age > 300 { // 5 minutes
		confidence *= 0.9
	}
	if age > 600 { // 10 minutes
		confidence *= 0.8
	}
	if age > 1800 { // 30 minutes
		confidence *= 0.6
	}

	result.Confidence = confidence
}

func (v *Validator) validateResponseFormat(response []byte) error {
	if len(response) == 0 {
		return fmt.Errorf("empty response")
	}

	// TODO: Add more specific validation based on response type
	// This could include checking JSON format, required fields, etc.

	return nil
}

func (v *Validator) createTaskResponseHash(taskIndex uint32, response []byte) common.Hash {
	// Create hash from task index and response
	data := append(big.NewInt(int64(taskIndex)).Bytes(), response...)
	hash := sha256.Sum256(data)
	return common.BytesToHash(hash[:])
}

func (v *Validator) SignMessage(privateKey *ecdsa.PrivateKey, messageHash common.Hash) ([]byte, error) {
	signature, err := crypto.Sign(messageHash.Bytes(), privateKey)
	if err != nil {
		return nil, fmt.Errorf("failed to sign message: %w", err)
	}

	// Remove recovery ID (last byte)
	return signature[:64], nil
}

func (v *Validator) GetDefaultValidationCriteria() *ValidationCriteria {
	return &ValidationCriteria{
		MaxPriceDeviation:    utils.MustSetString("1000000000000000000"), // 1 token (18 decimals)
		MaxLiquidityChange:   utils.MustSetString("1000000000000000000000"), // 1000 tokens
		MaxTimeGap:          300, // 5 minutes
		MinimumConfirmations: 1,
	}
}


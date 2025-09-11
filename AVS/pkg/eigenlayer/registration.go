package eigenlayer

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"

	"github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
)

type RegistrationManager struct {
	client Client
	logger logging.Logger
}

func NewRegistrationManager(client Client, logger logging.Logger) *RegistrationManager {
	return &RegistrationManager{
		client: client,
		logger: logger,
	}
}

func (rm *RegistrationManager) RegisterOperatorWithEigenLayer(
	ctx context.Context,
	operatorAddr common.Address,
	ecdsaPrivateKey *ecdsa.PrivateKey,
	metadataURI string,
) error {
	rm.logger.Info("Starting operator registration with EigenLayer",
		"operator", operatorAddr,
		"metadataURI", metadataURI,
	)

	// Check if already registered
	isRegistered, err := rm.client.IsOperatorRegistered(operatorAddr)
	if err != nil {
		return fmt.Errorf("failed to check operator registration status: %w", err)
	}

	if isRegistered {
		rm.logger.Info("Operator already registered", "operator", operatorAddr)
		return nil
	}

	// Register operator
	if err := rm.client.RegisterOperator(ctx, metadataURI); err != nil {
		return fmt.Errorf("failed to register operator: %w", err)
	}

	rm.logger.Info("Successfully registered operator with EigenLayer",
		"operator", operatorAddr,
		"metadataURI", metadataURI,
	)

	return nil
}

func (rm *RegistrationManager) ValidateOperatorRegistration(
	ctx context.Context,
	operatorAddr common.Address,
) error {
	rm.logger.Debug("Validating operator registration", "operator", operatorAddr)

	// Check if operator is registered
	isRegistered, err := rm.client.IsOperatorRegistered(operatorAddr)
	if err != nil {
		return fmt.Errorf("failed to check operator registration: %w", err)
	}

	if !isRegistered {
		return fmt.Errorf("operator not registered: %s", operatorAddr.Hex())
	}

	// Check operator stake
	stake, err := rm.client.GetOperatorStake(operatorAddr)
	if err != nil {
		return fmt.Errorf("failed to get operator stake: %w", err)
	}

	if stake.Cmp(big.NewInt(0)) == 0 {
		return fmt.Errorf("operator has no stake: %s", operatorAddr.Hex())
	}

	rm.logger.Info("Operator registration validated",
		"operator", operatorAddr,
		"stake", stake.String(),
	)

	return nil
}

func (rm *RegistrationManager) GetOperatorInfo(
	ctx context.Context,
	operatorAddr common.Address,
) (*OperatorInfo, error) {
	rm.logger.Debug("Getting operator info", "operator", operatorAddr)

	// Check registration status
	isRegistered, err := rm.client.IsOperatorRegistered(operatorAddr)
	if err != nil {
		return nil, fmt.Errorf("failed to check registration status: %w", err)
	}

	if !isRegistered {
		return nil, fmt.Errorf("operator not registered: %s", operatorAddr.Hex())
	}

	// Get stake amount
	stake, err := rm.client.GetOperatorStake(operatorAddr)
	if err != nil {
		return nil, fmt.Errorf("failed to get operator stake: %w", err)
	}

	return &OperatorInfo{
		Address:        operatorAddr,
		IsRegistered:   isRegistered,
		StakeAmount:    stake,
		MetadataURI:    "", // TODO: Get from contract
		RegistrationTime: 0, // TODO: Get from contract
	}, nil
}

type OperatorInfo struct {
	Address          common.Address `json:"address"`
	IsRegistered     bool           `json:"isRegistered"`
	StakeAmount      *big.Int       `json:"stakeAmount"`
	MetadataURI      string         `json:"metadataURI"`
	RegistrationTime uint64         `json:"registrationTime"`
}

// Helper function to create transaction options
func createTransactOpts(ctx context.Context, privateKey *ecdsa.PrivateKey, gasLimit uint64) (*bind.TransactOpts, error) {
	chainID := big.NewInt(1) // TODO: Get from config
	
	auth, err := bind.NewKeyedTransactorWithChainID(privateKey, chainID)
	if err != nil {
		return nil, fmt.Errorf("failed to create transactor: %w", err)
	}

	auth.Context = ctx
	auth.GasLimit = gasLimit

	return auth, nil
}

// Helper function to get public key from private key
func getPublicKey(privateKey *ecdsa.PrivateKey) common.Address {
	return crypto.PubkeyToAddress(privateKey.PublicKey)
}

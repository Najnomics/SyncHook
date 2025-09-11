package blockchain

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/sirupsen/logrus"
)

// ChainConfig holds blockchain configuration
type ChainConfig struct {
	ID           uint64 `mapstructure:"id"`
	Name         string `mapstructure:"name"`
	RPCURL       string `mapstructure:"rpc_url"`
	WSURL        string `mapstructure:"ws_url"`
	PrivateKey   string `mapstructure:"private_key"`
	SyncAVS      string `mapstructure:"sync_avs"`
	PoolManager  string `mapstructure:"pool_manager"`
	SyncHook     string `mapstructure:"sync_hook"`
	Confirmations int   `mapstructure:"confirmations"`
}

// Chain represents a blockchain connection
type Chain struct {
	ID           uint64
	Name         string
	Client       *ethclient.Client
	WSClient     *ethclient.Client
	PrivateKey   *ecdsa.PrivateKey
	Address      common.Address
	SyncAVS      common.Address
	PoolManager  common.Address
	SyncHook     common.Address
	Confirmations int
	logger       *logrus.Logger
}

// NewChain creates a new blockchain connection
func NewChain(cfg ChainConfig, logger *logrus.Logger) (*Chain, error) {
	// Parse private key
	privateKey, err := crypto.HexToECDSA(cfg.PrivateKey)
	if err != nil {
		return nil, fmt.Errorf("invalid private key: %w", err)
	}

	// Get public key and address
	publicKey := privateKey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		return nil, fmt.Errorf("error casting public key to ECDSA")
	}
	address := crypto.PubkeyToAddress(*publicKeyECDSA)

	// Connect to RPC
	client, err := ethclient.Dial(cfg.RPCURL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to RPC: %w", err)
	}

	// Connect to WebSocket (optional)
	var wsClient *ethclient.Client
	if cfg.WSURL != "" {
		wsClient, err = ethclient.Dial(cfg.WSURL)
		if err != nil {
			logger.WithError(err).Warn("Failed to connect to WebSocket, continuing without it")
		}
	}

	return &Chain{
		ID:           cfg.ID,
		Name:         cfg.Name,
		Client:       client,
		WSClient:     wsClient,
		PrivateKey:   privateKey,
		Address:      address,
		SyncAVS:      common.HexToAddress(cfg.SyncAVS),
		PoolManager:  common.HexToAddress(cfg.PoolManager),
		SyncHook:     common.HexToAddress(cfg.SyncHook),
		Confirmations: cfg.Confirmations,
		logger:       logger,
	}, nil
}

// Start starts the chain connection
func (c *Chain) Start() error {
	c.logger.WithField("chain_id", c.ID).Info("Starting blockchain connection")
	return nil
}

// Stop stops the chain connection
func (c *Chain) Stop() error {
	c.logger.WithField("chain_id", c.ID).Info("Stopping blockchain connection")
	c.Client.Close()
	if c.WSClient != nil {
		c.WSClient.Close()
	}
	return nil
}

// GetPoolStates retrieves current pool states from the chain
func (c *Chain) GetPoolStates() (map[string]interface{}, error) {
	// This is a simplified implementation
	// In a real implementation, you would:
	// 1. Query the PoolManager for all pools
	// 2. Get current liquidity, price, and other metrics
	// 3. Return structured data

	states := make(map[string]interface{})
	
	// Get latest block number
	blockNumber, err := c.Client.BlockNumber(context.Background())
	if err != nil {
		return nil, fmt.Errorf("failed to get block number: %w", err)
	}

	// Get chain ID
	chainID, err := c.Client.ChainID(context.Background())
	if err != nil {
		return nil, fmt.Errorf("failed to get chain ID: %w", err)
	}

	// Mock pool states (in real implementation, query actual pools)
	states["block_number"] = blockNumber
	states["chain_id"] = chainID.Uint64()
	states["timestamp"] = time.Now().Unix()
	states["pools"] = []map[string]interface{}{
		{
			"pool_id": "0x1234567890abcdef",
			"liquidity": "1000000000000000000000", // 1000 ETH
			"price": "2000000000000000000000", // 2000 USDC
			"volume_24h": "500000000000000000000", // 500 ETH
			"fees_24h": "1000000000000000000", // 1 ETH
		},
	}

	return states, nil
}

// SubmitStateUpdate submits state update to SyncAVS
func (c *Chain) SubmitStateUpdate(state map[string]interface{}) error {
	// This is a simplified implementation
	// In a real implementation, you would:
	// 1. Create a transaction to call SyncAVS.submitStateUpdate
	// 2. Sign and send the transaction
	// 3. Wait for confirmation

	c.logger.WithField("chain_id", c.ID).Debug("Submitting state update")
	
	// Mock implementation - in reality, you'd call the contract
	time.Sleep(100 * time.Millisecond)
	
	return nil
}

// GetTransactor returns a transactor for contract interactions
func (c *Chain) GetTransactor() *bind.TransactOpts {
	chainID, _ := c.Client.ChainID(context.Background())
	return &bind.TransactOpts{
		From:     c.Address,
		Signer:   c.getSigner(chainID),
		GasLimit: 300000,
		GasPrice: big.NewInt(20000000000), // 20 gwei
	}
}

// getSigner returns a signer function
func (c *Chain) getSigner(chainID *big.Int) bind.SignerFn {
	return func(address common.Address, tx *types.Transaction) (*types.Transaction, error) {
		return types.SignTx(tx, types.NewEIP155Signer(chainID), c.PrivateKey)
	}
}

// WaitForConfirmation waits for a transaction to be confirmed
func (c *Chain) WaitForConfirmation(txHash common.Hash) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	for {
		select {
		case <-ctx.Done():
			return fmt.Errorf("timeout waiting for confirmation")
		default:
			receipt, err := c.Client.TransactionReceipt(ctx, txHash)
			if err != nil {
				time.Sleep(1 * time.Second)
				continue
			}

			if receipt.Status == 1 {
				c.logger.WithField("tx_hash", txHash.Hex()).Info("Transaction confirmed")
				return nil
			}

			return fmt.Errorf("transaction failed")
		}
	}
}

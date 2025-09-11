package rebalancer

import (
	"context"
	"fmt"
	"math/big"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/synchook/avs/internal/across"
	"github.com/synchook/avs/internal/blockchain"
	"github.com/synchook/avs/internal/config"
	"github.com/synchook/avs/internal/database"
	"github.com/synchook/avs/internal/eigenlayer"
	"github.com/sirupsen/logrus"
)

// Rebalancer represents the liquidity rebalancing service
type Rebalancer struct {
	config     *config.Config
	chains     map[uint64]*blockchain.Chain
	eigenlayer *eigenlayer.Client
	across     map[uint64]*across.Client
	database   *database.Database
	logger     *logrus.Logger
	ctx        context.Context
	cancel     context.CancelFunc
	wg         sync.WaitGroup
}

// New creates a new rebalancer instance
func New(cfg *config.Config, chains map[uint64]*blockchain.Chain, eigenlayerClient *eigenlayer.Client, db *database.Database, logger *logrus.Logger) (*Rebalancer, error) {
	// Initialize Across Protocol clients for each chain
	acrossClients := make(map[uint64]*across.Client)
	for chainID, chain := range chains {
		acrossClient, err := across.NewClient(cfg.Across, chain.Client, logger)
		if err != nil {
			return nil, fmt.Errorf("failed to create Across client for chain %d: %w", chainID, err)
		}
		acrossClients[chainID] = acrossClient
	}

	return &Rebalancer{
		config:     cfg,
		chains:     chains,
		eigenlayer: eigenlayerClient,
		across:     acrossClients,
		database:   db,
		logger:     logger,
	}, nil
}

// Start starts the rebalancer
func (r *Rebalancer) Start(ctx context.Context) error {
	r.ctx, r.cancel = context.WithCancel(ctx)
	
	r.logger.Info("Starting liquidity rebalancer")
	
	// Start rebalancing routine
	r.wg.Add(1)
	go func() {
		defer r.wg.Done()
		r.rebalancingRoutine()
	}()

	// Wait for context cancellation
	<-r.ctx.Done()
	
	// Wait for rebalancing routine to finish
	r.wg.Wait()
	
	r.logger.Info("Liquidity rebalancer stopped")
	return nil
}

// rebalancingRoutine periodically checks for rebalancing opportunities
func (r *Rebalancer) rebalancingRoutine() {
	ticker := time.NewTicker(1 * time.Minute) // Check every minute
	defer ticker.Stop()

	for {
		select {
		case <-r.ctx.Done():
			return
		case <-ticker.C:
			r.checkRebalancingOpportunities()
		}
	}
}

// checkRebalancingOpportunities checks for rebalancing opportunities
func (r *Rebalancer) checkRebalancingOpportunities() {
	r.logger.Debug("Checking rebalancing opportunities")

	// Get current state from all chains
	chainStates := make(map[uint64]map[string]interface{})
	for chainID, chain := range r.chains {
		states, err := chain.GetPoolStates()
		if err != nil {
			r.logger.WithError(err).WithField("chain_id", chainID).Error("Failed to get chain states")
			continue
		}
		chainStates[chainID] = states
	}

	// Analyze rebalancing opportunities
	opportunities, err := r.analyzeRebalancingOpportunities(chainStates)
	if err != nil {
		r.logger.WithError(err).Error("Failed to analyze rebalancing opportunities")
		return
	}

	// Execute rebalancing if opportunities exist
	if len(opportunities) > 0 {
		r.executeRebalancing(opportunities)
	}
}

// analyzeRebalancingOpportunities analyzes potential rebalancing opportunities
func (r *Rebalancer) analyzeRebalancingOpportunities(chainStates map[uint64]map[string]interface{}) ([]RebalancingOpportunity, error) {
	// This is a simplified implementation
	// In a real implementation, you would:
	// 1. Compare prices across chains
	// 2. Calculate arbitrage opportunities
	// 3. Determine optimal rebalancing amounts
	// 4. Check if rebalancing is profitable after fees

	var opportunities []RebalancingOpportunity

	// Mock implementation - create a sample opportunity
	opportunity := RebalancingOpportunity{
		FromChain:   1,
		ToChain:     42161, // Arbitrum
		Token:       "0x1234567890abcdef",
		Amount:      "100000000000000000000", // 100 ETH
		ExpectedProfit: "5000000000000000000", // 5 ETH
		Priority:    1,
	}

	opportunities = append(opportunities, opportunity)

	r.logger.WithField("opportunities", len(opportunities)).Debug("Rebalancing opportunities analyzed")
	return opportunities, nil
}

// executeRebalancing executes rebalancing operations
func (r *Rebalancer) executeRebalancing(opportunities []RebalancingOpportunity) {
	r.logger.WithField("count", len(opportunities)).Info("Executing rebalancing operations")

	for _, opportunity := range opportunities {
		if err := r.executeRebalancingOperation(opportunity); err != nil {
			r.logger.WithError(err).WithField("opportunity", opportunity).Error("Failed to execute rebalancing operation")
			continue
		}
	}
}

// executeRebalancingOperation executes a single rebalancing operation
func (r *Rebalancer) executeRebalancingOperation(opportunity RebalancingOpportunity) error {
	r.logger.WithField("opportunity", opportunity).Info("Executing rebalancing operation")

	// Get the source chain and Across client
	sourceChain, exists := r.chains[opportunity.FromChain]
	if !exists {
		return fmt.Errorf("source chain %d not found", opportunity.FromChain)
	}

	acrossClient, exists := r.across[opportunity.FromChain]
	if !exists {
		return fmt.Errorf("Across client for chain %d not found", opportunity.FromChain)
	}

	// Parse amount
	amount, ok := new(big.Int).SetString(opportunity.Amount, 10)
	if !ok {
		return fmt.Errorf("invalid amount: %s", opportunity.Amount)
	}

	// Create cross-chain transfer
	transfer := &across.CrossChainTransfer{
		FromChain:   opportunity.FromChain,
		ToChain:     opportunity.ToChain,
		Token:       common.HexToAddress(opportunity.Token),
		Amount:      amount,
		Recipient:   sourceChain.Address, // Send to operator address
		RelayerFee:  acrossClient.CalculateRelayerFee(amount),
		Message:     []byte("SyncHook rebalancing"),
		MaxGasPrice: big.NewInt(20000000000), // 20 gwei
		MaxGasLimit: big.NewInt(300000),
	}

	// Get transactor for the source chain
	transactor := sourceChain.GetTransactor()

	// Initiate transfer
	result, err := acrossClient.InitiateTransfer(r.ctx, transfer, transactor)
	if err != nil {
		return fmt.Errorf("failed to initiate transfer: %w", err)
	}

	r.logger.WithFields(logrus.Fields{
		"tx_hash":    result.TransactionHash.Hex(),
		"deposit_id": result.DepositID.String(),
	}).Info("Cross-chain transfer initiated")

	// Monitor transfer status
	go r.monitorTransfer(opportunity, result)

	return nil
}

// monitorTransfer monitors a cross-chain transfer
func (r *Rebalancer) monitorTransfer(opportunity RebalancingOpportunity, result *across.TransferResult) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	acrossClient := r.across[opportunity.FromChain]

	for {
		select {
		case <-r.ctx.Done():
			return
		case <-ticker.C:
			complete, err := acrossClient.IsTransferComplete(r.ctx, result.DepositID)
			if err != nil {
				r.logger.WithError(err).WithField("deposit_id", result.DepositID.String()).Error("Failed to check transfer status")
				continue
			}

			if complete {
				r.logger.WithFields(logrus.Fields{
					"deposit_id": result.DepositID.String(),
					"tx_hash":    result.TransactionHash.Hex(),
				}).Info("Cross-chain transfer completed")
				return
			}

			r.logger.WithField("deposit_id", result.DepositID.String()).Debug("Transfer still pending")
		}
	}
}

// RebalancingOpportunity represents a rebalancing opportunity
type RebalancingOpportunity struct {
	FromChain      uint64 `json:"from_chain"`
	ToChain        uint64 `json:"to_chain"`
	Token          string `json:"token"`
	Amount         string `json:"amount"`
	ExpectedProfit string `json:"expected_profit"`
	Priority       int    `json:"priority"`
}

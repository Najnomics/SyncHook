package operator

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/synchook/avs/internal/blockchain"
	"github.com/synchook/avs/internal/config"
	"github.com/synchook/avs/internal/database"
	"github.com/synchook/avs/internal/eigenlayer"
	"github.com/synchook/avs/internal/monitor"
	"github.com/synchook/avs/internal/rebalancer"
	"github.com/sirupsen/logrus"
)

// Operator represents the main SyncHook operator
type Operator struct {
	config     *config.Config
	logger     *logrus.Logger
	database   *database.Database
	monitor    *monitor.Monitor
	rebalancer *rebalancer.Rebalancer
	chains     map[uint64]*blockchain.Chain
	eigenlayer *eigenlayer.Client
	ctx        context.Context
	cancel     context.CancelFunc
	wg         sync.WaitGroup
}

// New creates a new operator instance
func New(cfg *config.Config, logger *logrus.Logger) (*Operator, error) {
	ctx, cancel := context.WithCancel(context.Background())

	// Initialize database
	db, err := database.New(cfg.GetDatabaseDSN(), logger)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to initialize database: %w", err)
	}

	// Initialize blockchain clients
	chains := make(map[uint64]*blockchain.Chain)
	for _, chainCfg := range cfg.Chains {
		chain, err := blockchain.NewChain(chainCfg, logger)
		if err != nil {
			cancel()
			return nil, fmt.Errorf("failed to initialize chain %d: %w", chainCfg.ID, err)
		}
		chains[chainCfg.ID] = chain
	}

	// Initialize EigenLayer client
	eigenlayerClient, err := eigenlayer.NewClient(cfg.EigenLayer, logger)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to initialize EigenLayer client: %w", err)
	}

	// Initialize monitor
	monitor, err := monitor.New(cfg, chains, db, logger)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to initialize monitor: %w", err)
	}

	// Initialize rebalancer
	rebalancer, err := rebalancer.New(cfg, chains, eigenlayerClient, db, logger)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to initialize rebalancer: %w", err)
	}

	return &Operator{
		config:     cfg,
		logger:     logger,
		database:   db,
		monitor:    monitor,
		rebalancer: rebalancer,
		chains:     chains,
		eigenlayer: eigenlayerClient,
		ctx:        ctx,
		cancel:     cancel,
	}, nil
}

// Run starts the operator
func (o *Operator) Run(ctx context.Context) error {
	o.logger.Info("Starting SyncHook Operator")

	// Start database
	if err := o.database.Start(); err != nil {
		return fmt.Errorf("failed to start database: %w", err)
	}
	defer o.database.Stop()

	// Start blockchain clients
	for chainID, chain := range o.chains {
		if err := chain.Start(); err != nil {
			return fmt.Errorf("failed to start chain %d: %w", chainID, err)
		}
		defer chain.Stop()
	}

	// Start EigenLayer client
	if err := o.eigenlayer.Start(); err != nil {
		return fmt.Errorf("failed to start EigenLayer client: %w", err)
	}
	defer o.eigenlayer.Stop()

	// Start monitor
	o.wg.Add(1)
	go func() {
		defer o.wg.Done()
		if err := o.monitor.Start(o.ctx); err != nil {
			o.logger.WithError(err).Error("Monitor failed")
		}
	}()

	// Start rebalancer
	o.wg.Add(1)
	go func() {
		defer o.wg.Done()
		if err := o.rebalancer.Start(o.ctx); err != nil {
			o.logger.WithError(err).Error("Rebalancer failed")
		}
	}()

	// Start state update routine
	o.wg.Add(1)
	go func() {
		defer o.wg.Done()
		o.stateUpdateRoutine()
	}()

	// Wait for context cancellation
	<-ctx.Done()
	o.logger.Info("Shutting down operator...")

	// Cancel internal context
	o.cancel()

	// Wait for all goroutines to finish
	o.wg.Wait()

	o.logger.Info("Operator stopped")
	return nil
}

// stateUpdateRoutine periodically updates state across chains
func (o *Operator) stateUpdateRoutine() {
	ticker := time.NewTicker(o.config.Operator.StateUpdateInterval)
	defer ticker.Stop()

	for {
		select {
		case <-o.ctx.Done():
			return
		case <-ticker.C:
			o.updateState()
		}
	}
}

// updateState updates state across all chains
func (o *Operator) updateState() {
	o.logger.Debug("Updating state across chains")

	// Get current state from all chains
	states := make(map[uint64]map[string]interface{})
	for chainID, chain := range o.chains {
		state, err := chain.GetPoolStates()
		if err != nil {
			o.logger.WithError(err).WithField("chain_id", chainID).Error("Failed to get pool states")
			continue
		}
		states[chainID] = state
	}

	// Submit state updates to EigenLayer
	for chainID, state := range states {
		if err := o.eigenlayer.SubmitStateUpdate(chainID, state); err != nil {
			o.logger.WithError(err).WithField("chain_id", chainID).Error("Failed to submit state update")
			continue
		}
		o.logger.WithField("chain_id", chainID).Debug("State update submitted")
	}
}

// Stop stops the operator
func (o *Operator) Stop() {
	o.cancel()
	o.wg.Wait()
}

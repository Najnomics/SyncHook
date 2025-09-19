package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"github.com/synchook/synchook/AVS/internal/config"
	"github.com/synchook/synchook/AVS/internal/logger"
	"github.com/synchook/synchook/AVS/internal/operator"
)

var (
	version = "2.0.0"
	commit  = "unknown"
)

func main() {
	var rootCmd = &cobra.Command{
		Use:   "synchook-avs-operator",
		Short: "SyncHook AVS Operator - Cross-chain liquidity synchronization service",
		Long: `SyncHook AVS Operator is a comprehensive service that monitors and coordinates
cross-chain liquidity synchronization across multiple blockchains using
EigenLayer's Actively Validated Service infrastructure and Across Protocol integration.

The operator monitors Uniswap V4 pools across Ethereum, Arbitrum, Polygon, Base, and Optimism,
providing intelligent rebalancing and cross-chain state synchronization.`,
		Version: fmt.Sprintf("%s (commit: %s)", version, commit),
	}

	var configFile string
	rootCmd.PersistentFlags().StringVar(&configFile, "config", "config.yaml", "config file path")

	var startCmd = &cobra.Command{
		Use:   "start",
		Short: "Start the SyncHook AVS operator",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runOperator(configFile)
		},
	}

	var monitorCmd = &cobra.Command{
		Use:   "monitor",
		Short: "Start monitoring mode",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runMonitor(configFile)
		},
	}

	rootCmd.AddCommand(startCmd)
	rootCmd.AddCommand(monitorCmd)

	if err := rootCmd.Execute(); err != nil {
		logrus.Fatal(err)
	}
}

func runOperator(configFile string) error {
	// Load configuration
	cfg, err := config.Load(configFile)
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Initialize logger
	log, err := logger.New(cfg.Log)
	if err != nil {
		return fmt.Errorf("failed to initialize logger: %w", err)
	}

	log.Info("Starting SyncHook AVS Operator", "version", version, "commit", commit)

	// Create operator instance
	op, err := operator.New(cfg, log)
	if err != nil {
		return fmt.Errorf("failed to create operator: %w", err)
	}

	// Start operator
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		sig := <-sigChan
		log.Info("Received shutdown signal", "signal", sig)
		cancel()
	}()

	// Run operator
	if err := op.Run(ctx); err != nil {
		return fmt.Errorf("operator failed: %w", err)
	}

	log.Info("SyncHook AVS Operator stopped gracefully")
	return nil
}

func runMonitor(configFile string) error {
	// Load configuration
	cfg, err := config.Load(configFile)
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Initialize logger
	log, err := logger.New(cfg.Log)
	if err != nil {
		return fmt.Errorf("failed to initialize logger: %w", err)
	}

	log.Info("Starting SyncHook AVS Monitor", "version", version, "commit", commit)

	// Create operator instance for monitoring
	op, err := operator.New(cfg, log)
	if err != nil {
		return fmt.Errorf("failed to create operator: %w", err)
	}

	// Start monitoring mode
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		sig := <-sigChan
		log.Info("Received shutdown signal", "signal", sig)
		cancel()
	}()

	// Run in monitoring mode
	if err := op.Monitor(ctx); err != nil {
		return fmt.Errorf("monitor failed: %w", err)
	}

	log.Info("SyncHook AVS Monitor stopped gracefully")
	return nil
}

package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/synchook/synchook-avs/internal/config"
	"github.com/synchook/synchook-avs/internal/operator"
	"github.com/synchook/synchook-avs/internal/logger"
	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var (
	version = "dev"
	commit  = "unknown"
)

func main() {
	var rootCmd = &cobra.Command{
		Use:   "synchook-operator",
		Short: "SyncHook Operator - Cross-chain liquidity synchronization service",
		Long: `SyncHook Operator is a service that monitors and coordinates
cross-chain liquidity synchronization across multiple blockchains using
EigenLayer AVS and Across Protocol integration.`,
		Version: fmt.Sprintf("%s (commit: %s)", version, commit),
	}

	var configFile string
	rootCmd.PersistentFlags().StringVar(&configFile, "config", "config.yaml", "config file path")

	var startCmd = &cobra.Command{
		Use:   "start",
		Short: "Start the SyncHook operator",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runOperator(configFile)
		},
	}

	rootCmd.AddCommand(startCmd)

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

	log.Info("Starting SyncHook Operator", "version", version, "commit", commit)

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

	log.Info("SyncHook Operator stopped gracefully")
	return nil
}
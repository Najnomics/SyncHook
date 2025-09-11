package main

import (
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/synchook/operator/operator"
	"github.com/synchook/operator/pkg/config"
)

var (
	configFile = flag.String("config", "config/operator.yaml", "Path to operator config file")
	help       = flag.Bool("help", false, "Show help")
)

func main() {
	flag.Parse()

	if *help {
		flag.Usage()
		os.Exit(0)
	}

	logger, err := logging.NewZapLogger(logging.Development)
	if err != nil {
		log.Fatalf("Failed to create logger: %v", err)
	}

	logger.Info("Starting SyncHook AVS Operator")

	// Load configuration
	config, err := loadConfig(*configFile)
	if err != nil {
		logger.Fatal("Failed to load config", "error", err)
	}

	// Create operator
	op, err := operator.NewOperator(config, logger)
	if err != nil {
		logger.Fatal("Failed to create operator", "error", err)
	}

	// Set up context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle shutdown signals
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		sig := <-sigChan
		logger.Info("Received shutdown signal", "signal", sig)
		cancel()
	}()

	// Start operator
	logger.Info("Starting SyncHook operator with config", 
		"ethRpcUrl", config.EthRpcUrl,
		"registryCoordinator", config.RegistryCoordinatorAddress,
		"aggregatorAddr", config.AggregatorServerIpPortAddr,
		"syncAVSAddress", config.SyncAVSAddress,
		"acrossAddress", config.AcrossAddress,
	)

	if err := op.Start(ctx); err != nil {
		logger.Fatal("Operator failed", "error", err)
	}

	logger.Info("SyncHook operator stopped gracefully")
}

func loadConfig(configPath string) (*config.Config, error) {
	// Check if config file exists
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		// Use default config if file doesn't exist
		return config.GetDefaultConfig(), nil
	}

	// Load from file
	return config.LoadConfig(configPath)
}

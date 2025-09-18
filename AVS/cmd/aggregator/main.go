package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/synchook/synchook-avs/aggregator"
)

var (
	configFile = flag.String("config", "config/aggregator.yaml", "Path to aggregator config file")
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

	logger.Info("Starting SyncHook AVS Aggregator")

	// Load configuration
	config, err := loadConfig(*configFile)
	if err != nil {
		logger.Fatal("Failed to load config", "error", err)
	}

	// Create aggregator
	agg, err := aggregator.NewSyncHookAggregator(config, logger)
	if err != nil {
		logger.Fatal("Failed to create aggregator", "error", err)
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

	// Start aggregator
	logger.Info("Starting SyncHook aggregator with config", 
		"serverAddress", config.ServerIpPortAddress,
		"ethRpcUrl", config.EthRpcUrl,
		"syncAVSAddress", config.SyncAVSAddress,
		"acrossAddress", config.AcrossAddress,
	)

	if err := agg.Start(ctx); err != nil {
		logger.Fatal("Aggregator failed", "error", err)
	}

	logger.Info("SyncHook aggregator stopped gracefully")
}

func loadConfig(configPath string) (aggregator.Config, error) {
	var config aggregator.Config

	// Check if config file exists
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		// Use default config if file doesn't exist
		config = aggregator.Config{
			ServerIpPortAddress:         "localhost:8090",
			EnableGrpc:                  true,
			EnableHttp:                  true,
			HttpPort:                    8080,
			RegistryCoordinatorAddress:  "0x0000000000000000000000000000000000000000",
			OperatorStateRetrieverAddress: "0x0000000000000000000000000000000000000000",
			EthRpcUrl:                   "http://localhost:8545",
			EthWsUrl:                    "ws://localhost:8546",
			SyncAVSAddress:              "0x0000000000000000000000000000000000000000",
			AcrossAddress:               "0x0000000000000000000000000000000000000000",
			TaskTimeout:                 300,
			MaxConcurrentTasks:          100,
			TaskRetryAttempts:           3,
			TaskRetryDelay:              30,
			StateUpdateInterval:         30,
			StateValidationThreshold:    0.8,
			MaxStateAge:                 600,
			RebalancingEnabled:          true,
			RebalancingThreshold:        0.05,
			MaxRebalancingAmount:        "1000000000000000000000000",
			MinRebalancingAmount:        "1000000000000000000000",
			RebalancingTimeout:          1800,
			EnableMetrics:               true,
			MetricsPort:                 9090,
			EnableHealthCheck:           true,
			HealthCheckInterval:         30,
			LogLevel:                    "info",
			LogFormat:                   "json",
		}
		
		return config, nil
	}

	// Load from file
	file, err := os.Open(configPath)
	if err != nil {
		return config, fmt.Errorf("failed to open config file: %w", err)
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&config); err != nil {
		return config, fmt.Errorf("failed to decode config: %w", err)
	}

	return config, nil
}

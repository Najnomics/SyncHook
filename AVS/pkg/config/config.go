package config

import (
	"encoding/json"
	"fmt"
	"math/big"
	"os"
	"time"
)

// Config represents the main configuration structure
type Config struct {
	// Operator Identity
	EcdsaPrivateKeyStorePath   string `json:"ecdsa_private_key_store_path"`
	BlsPrivateKeyStorePath     string `json:"bls_private_key_store_path"`

	// Ethereum Configuration
	EthRpcUrl                  string `json:"eth_rpc_url"`
	EthWsUrl                   string `json:"eth_ws_url"`

	// EigenLayer Configuration
	RegistryCoordinatorAddress  string `json:"registry_coordinator_address"`
	OperatorStateRetrieverAddress string `json:"operator_state_retriever_address"`
	AggregatorServerIpPortAddr string `json:"aggregator_server_ip_port_address"`
	RegisterOperatorOnStartup  bool   `json:"register_operator_on_startup"`

	// Metrics Configuration
	EigenMetricsIpPortAddress  string `json:"eigen_metrics_ip_port_address"`
	EnableMetrics              bool   `json:"enable_metrics"`

	// Node API Configuration
	NodeApiIpPortAddress       string `json:"node_api_ip_port_address"`
	EnableNodeApi              bool   `json:"enable_node_api"`

	// SyncHook Specific Configuration
	SyncAVSAddress           string         `json:"sync_avs_address"`
	AcrossAddress            string         `json:"across_address"`
	SupportedChains          []ChainConfig  `json:"supported_chains"`
	StateUpdateInterval      int            `json:"state_update_interval"`
	RebalancingThreshold     float64        `json:"rebalancing_threshold"`
	MaxRebalancingAmount     string         `json:"max_rebalancing_amount"`
	MinRebalancingAmount     string         `json:"min_rebalancing_amount"`

	// Monitoring Configuration
	EnableMonitoring          bool           `json:"enable_monitoring"`
	AlertThresholds           AlertThresholds `json:"alert_thresholds"`

	// Logging Configuration
	LogLevel                  string         `json:"log_level"`
	LogFormat                 string         `json:"log_format"`
}

// ChainConfig represents configuration for a supported blockchain
type ChainConfig struct {
	ChainID   uint32 `json:"chain_id"`
	Name      string `json:"name"`
	RpcUrl    string `json:"rpc_url"`
	BlockTime int    `json:"block_time"`
	GasPrice  int64  `json:"gas_price"`
}

// AlertThresholds represents alert configuration thresholds
type AlertThresholds struct {
	PriceDeviation    float64 `json:"price_deviation"`
	LiquidityImbalance float64 `json:"liquidity_imbalance"`
	ResponseTime      int     `json:"response_time"`
}

// AggregatorConfig represents the aggregator configuration
type AggregatorConfig struct {
	// Server Configuration
	ServerIpPortAddress         string  `json:"server_ip_port_address"`
	EnableGrpc                  bool    `json:"enable_grpc"`
	EnableHttp                  bool    `json:"enable_http"`
	HttpPort                    int     `json:"http_port"`

	// EigenLayer Configuration
	RegistryCoordinatorAddress  string  `json:"registry_coordinator_address"`
	OperatorStateRetrieverAddress string `json:"operator_state_retriever_address"`

	// Ethereum Configuration
	EthRpcUrl                   string  `json:"eth_rpc_url"`
	EthWsUrl                    string  `json:"eth_ws_url"`

	// SyncHook Specific Configuration
	SyncAVSAddress              string  `json:"sync_avs_address"`
	AcrossAddress               string  `json:"across_address"`

	// Task Management
	TaskTimeout                 int     `json:"task_timeout"`
	MaxConcurrentTasks          int     `json:"max_concurrent_tasks"`
	TaskRetryAttempts           int     `json:"task_retry_attempts"`
	TaskRetryDelay              int     `json:"task_retry_delay"`

	// State Aggregation
	StateUpdateInterval         int     `json:"state_update_interval"`
	StateValidationThreshold    float64 `json:"state_validation_threshold"`
	MaxStateAge                 int     `json:"max_state_age"`

	// Rebalancing Configuration
	RebalancingEnabled          bool    `json:"rebalancing_enabled"`
	RebalancingThreshold        float64 `json:"rebalancing_threshold"`
	MaxRebalancingAmount        string  `json:"max_rebalancing_amount"`
	MinRebalancingAmount        string  `json:"min_rebalancing_amount"`
	RebalancingTimeout          int     `json:"rebalancing_timeout"`

	// Monitoring
	EnableMetrics               bool    `json:"enable_metrics"`
	MetricsPort                 int     `json:"metrics_port"`
	EnableHealthCheck           bool    `json:"enable_health_check"`
	HealthCheckInterval         int     `json:"health_check_interval"`

	// Logging
	LogLevel                    string  `json:"log_level"`
	LogFormat                   string  `json:"log_format"`
	LogFile                     string  `json:"log_file"`

	// Database
	Database                    DatabaseConfig `json:"database"`

	// Security
	EnableTls                   bool    `json:"enable_tls"`
	TlsCertFile                 string  `json:"tls_cert_file"`
	TlsKeyFile                  string  `json:"tls_key_file"`
	ApiKeyRequired              bool    `json:"api_key_required"`
	ApiKey                      string  `json:"api_key"`

	// Performance
	MaxRequestSize              int64   `json:"max_request_size"`
	RequestTimeout              int     `json:"request_timeout"`
	ResponseTimeout             int     `json:"response_timeout"`
}

// DatabaseConfig represents database configuration
type DatabaseConfig struct {
	Type             string `json:"type"`
	ConnectionString string `json:"connection_string"`
	MaxConnections   int    `json:"max_connections"`
	ConnectionTimeout int   `json:"connection_timeout"`
}

// LoadConfig loads configuration from a JSON file
func LoadConfig(configPath string) (*Config, error) {
	file, err := os.Open(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open config file: %w", err)
	}
	defer file.Close()

	var config Config
	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&config); err != nil {
		return nil, fmt.Errorf("failed to decode config: %w", err)
	}

	return &config, nil
}

// LoadAggregatorConfig loads aggregator configuration from a JSON file
func LoadAggregatorConfig(configPath string) (*AggregatorConfig, error) {
	file, err := os.Open(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open config file: %w", err)
	}
	defer file.Close()

	var config AggregatorConfig
	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&config); err != nil {
		return nil, fmt.Errorf("failed to decode config: %w", err)
	}

	return &config, nil
}

// GetDefaultConfig returns default configuration
func GetDefaultConfig() *Config {
	return &Config{
		EcdsaPrivateKeyStorePath:      "./keys/operator.ecdsa.key.json",
		BlsPrivateKeyStorePath:        "./keys/operator.bls.key.json",
		EthRpcUrl:                     "http://localhost:8545",
		EthWsUrl:                      "ws://localhost:8546",
		RegistryCoordinatorAddress:    "0x0000000000000000000000000000000000000000",
		OperatorStateRetrieverAddress: "0x0000000000000000000000000000000000000000",
		AggregatorServerIpPortAddr:    "localhost:8090",
		RegisterOperatorOnStartup:     true,
		EigenMetricsIpPortAddress:     "localhost:9090",
		EnableMetrics:                 true,
		NodeApiIpPortAddress:          "localhost:9091",
		EnableNodeApi:                 true,
		SyncAVSAddress:                "0x0000000000000000000000000000000000000000",
		AcrossAddress:                 "0x0000000000000000000000000000000000000000",
		SupportedChains: []ChainConfig{
			{
				ChainID:   1,
				Name:      "Ethereum",
				RpcUrl:    "http://localhost:8545",
				BlockTime: 12,
				GasPrice:  20000000000,
			},
			{
				ChainID:   42161,
				Name:      "Arbitrum",
				RpcUrl:    "http://localhost:8547",
				BlockTime: 1,
				GasPrice:  1000000000,
			},
			{
				ChainID:   137,
				Name:      "Polygon",
				RpcUrl:    "http://localhost:8548",
				BlockTime: 2,
				GasPrice:  30000000000,
			},
		},
		StateUpdateInterval:      30,
		RebalancingThreshold:     0.05,
		MaxRebalancingAmount:     "1000000000000000000000000",
		MinRebalancingAmount:     "1000000000000000000000",
		EnableMonitoring:         true,
		AlertThresholds: AlertThresholds{
			PriceDeviation:     0.1,
			LiquidityImbalance: 0.2,
			ResponseTime:       30,
		},
		LogLevel:  "info",
		LogFormat: "json",
	}
}

// GetDefaultAggregatorConfig returns default aggregator configuration
func GetDefaultAggregatorConfig() *AggregatorConfig {
	return &AggregatorConfig{
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
		LogFile:                     "./logs/aggregator.log",
		Database: DatabaseConfig{
			Type:             "sqlite",
			ConnectionString: "./data/aggregator.db",
			MaxConnections:   10,
			ConnectionTimeout: 30,
		},
		EnableTls:        false,
		ApiKeyRequired:   false,
		MaxRequestSize:   10485760, // 10MB
		RequestTimeout:   30,
		ResponseTimeout:  60,
	}
}

// Validate validates the configuration
func (c *Config) Validate() error {
	if c.EcdsaPrivateKeyStorePath == "" {
		return fmt.Errorf("ecdsa_private_key_store_path is required")
	}
	if c.BlsPrivateKeyStorePath == "" {
		return fmt.Errorf("bls_private_key_store_path is required")
	}
	if c.EthRpcUrl == "" {
		return fmt.Errorf("eth_rpc_url is required")
	}
	if c.RegistryCoordinatorAddress == "" {
		return fmt.Errorf("registry_coordinator_address is required")
	}
	if c.SyncAVSAddress == "" {
		return fmt.Errorf("sync_avs_address is required")
	}
	if c.AcrossAddress == "" {
		return fmt.Errorf("across_address is required")
	}
	if len(c.SupportedChains) == 0 {
		return fmt.Errorf("at least one supported chain is required")
	}
	return nil
}

// Validate validates the aggregator configuration
func (c *AggregatorConfig) Validate() error {
	if c.ServerIpPortAddress == "" {
		return fmt.Errorf("server_ip_port_address is required")
	}
	if c.EthRpcUrl == "" {
		return fmt.Errorf("eth_rpc_url is required")
	}
	if c.RegistryCoordinatorAddress == "" {
		return fmt.Errorf("registry_coordinator_address is required")
	}
	if c.SyncAVSAddress == "" {
		return fmt.Errorf("sync_avs_address is required")
	}
	if c.AcrossAddress == "" {
		return fmt.Errorf("across_address is required")
	}
	return nil
}

// GetChainConfig returns configuration for a specific chain
func (c *Config) GetChainConfig(chainID uint32) (*ChainConfig, error) {
	for _, chain := range c.SupportedChains {
		if chain.ChainID == chainID {
			return &chain, nil
		}
	}
	return nil, fmt.Errorf("chain %d not supported", chainID)
}

// GetSupportedChainIDs returns list of supported chain IDs
func (c *Config) GetSupportedChainIDs() []uint32 {
	chainIDs := make([]uint32, len(c.SupportedChains))
	for i, chain := range c.SupportedChains {
		chainIDs[i] = chain.ChainID
	}
	return chainIDs
}

// IsChainSupported checks if a chain is supported
func (c *Config) IsChainSupported(chainID uint32) bool {
	_, err := c.GetChainConfig(chainID)
	return err == nil
}

// GetStateUpdateInterval returns the state update interval as duration
func (c *Config) GetStateUpdateInterval() time.Duration {
	return time.Duration(c.StateUpdateInterval) * time.Second
}

// GetRebalancingThreshold returns the rebalancing threshold as a decimal
func (c *Config) GetRebalancingThreshold() float64 {
	return c.RebalancingThreshold
}

// GetMaxRebalancingAmount returns the max rebalancing amount as big.Int
func (c *Config) GetMaxRebalancingAmount() (*big.Int, error) {
	amount, ok := new(big.Int).SetString(c.MaxRebalancingAmount, 10)
	if !ok {
		return nil, fmt.Errorf("invalid max_rebalancing_amount: %s", c.MaxRebalancingAmount)
	}
	return amount, nil
}

// GetMinRebalancingAmount returns the min rebalancing amount as big.Int
func (c *Config) GetMinRebalancingAmount() (*big.Int, error) {
	amount, ok := new(big.Int).SetString(c.MinRebalancingAmount, 10)
	if !ok {
		return nil, fmt.Errorf("invalid min_rebalancing_amount: %s", c.MinRebalancingAmount)
	}
	return amount, nil
}

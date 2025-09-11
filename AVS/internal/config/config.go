package config

import (
	"fmt"
	"os"
	"time"

	"github.com/joho/godotenv"
	"github.com/spf13/viper"
)

// Config represents the application configuration
type Config struct {
	Server   ServerConfig   `mapstructure:"server"`
	Database DatabaseConfig `mapstructure:"database"`
	Chains   []ChainConfig  `mapstructure:"chains"`
	EigenLayer EigenLayerConfig `mapstructure:"eigenlayer"`
	Across   AcrossConfig   `mapstructure:"across"`
	Log      LogConfig      `mapstructure:"log"`
	Operator OperatorConfig `mapstructure:"operator"`
}

// ServerConfig holds server configuration
type ServerConfig struct {
	Host string `mapstructure:"host"`
	Port int    `mapstructure:"port"`
}

// DatabaseConfig holds database configuration
type DatabaseConfig struct {
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	User     string `mapstructure:"user"`
	Password string `mapstructure:"password"`
	DBName   string `mapstructure:"dbname"`
	SSLMode  string `mapstructure:"sslmode"`
}

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

// EigenLayerConfig holds EigenLayer configuration
type EigenLayerConfig struct {
	RegistryCoordinator string `mapstructure:"registry_coordinator"`
	StakeRegistry       string `mapstructure:"stake_registry"`
	BLSApkRegistry      string `mapstructure:"bls_apk_registry"`
	IndexRegistry       string `mapstructure:"index_registry"`
	OperatorID          uint32 `mapstructure:"operator_id"`
	QuorumNumber        uint8  `mapstructure:"quorum_number"`
}

// AcrossConfig holds Across Protocol configuration
type AcrossConfig struct {
	SpokePool     string `mapstructure:"spoke_pool"`
	HubPool       string `mapstructure:"hub_pool"`
	RelayerFeePct string `mapstructure:"relayer_fee_pct"`
	MaxGasPrice   string `mapstructure:"max_gas_price"`
}

// LogConfig holds logging configuration
type LogConfig struct {
	Level  string `mapstructure:"level"`
	Format string `mapstructure:"format"`
	Output string `mapstructure:"output"`
}

// OperatorConfig holds operator-specific configuration
type OperatorConfig struct {
	StateUpdateInterval time.Duration `mapstructure:"state_update_interval"`
	RebalanceThreshold  float64       `mapstructure:"rebalance_threshold"`
	MaxRebalanceAmount  string        `mapstructure:"max_rebalance_amount"`
	MinRebalanceAmount  string        `mapstructure:"min_rebalance_amount"`
	RebalanceCooldown   time.Duration `mapstructure:"rebalance_cooldown"`
}

// Load loads configuration from file and environment variables
func Load(configFile string) (*Config, error) {
	// Load .env file if it exists
	if err := godotenv.Load(); err != nil {
		// .env file is optional
	}

	// Set up viper
	viper.SetConfigFile(configFile)
	viper.SetConfigType("yaml")
	viper.AutomaticEnv()

	// Set default values
	setDefaults()

	// Read config file
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("failed to read config file: %w", err)
		}
		// Config file not found, use defaults and env vars
	}

	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	// Validate configuration
	if err := validate(&config); err != nil {
		return nil, fmt.Errorf("invalid configuration: %w", err)
	}

	return &config, nil
}

// setDefaults sets default configuration values
func setDefaults() {
	// Server defaults
	viper.SetDefault("server.host", "0.0.0.0")
	viper.SetDefault("server.port", 8080)

	// Database defaults
	viper.SetDefault("database.host", "localhost")
	viper.SetDefault("database.port", 5432)
	viper.SetDefault("database.user", "synchook")
	viper.SetDefault("database.dbname", "synchook")
	viper.SetDefault("database.sslmode", "disable")

	// Log defaults
	viper.SetDefault("log.level", "info")
	viper.SetDefault("log.format", "json")
	viper.SetDefault("log.output", "stdout")

	// Operator defaults
	viper.SetDefault("operator.state_update_interval", "30s")
	viper.SetDefault("operator.rebalance_threshold", 0.2) // 20%
	viper.SetDefault("operator.max_rebalance_amount", "1000000000000000000000") // 1000 ETH
	viper.SetDefault("operator.min_rebalance_amount", "1000000000000000000")    // 1 ETH
	viper.SetDefault("operator.rebalance_cooldown", "300s") // 5 minutes
}

// validate validates the configuration
func validate(config *Config) error {
	if len(config.Chains) == 0 {
		return fmt.Errorf("at least one chain must be configured")
	}

	for i, chain := range config.Chains {
		if chain.RPCURL == "" {
			return fmt.Errorf("chain %d: RPC URL is required", i)
		}
		if chain.PrivateKey == "" {
			return fmt.Errorf("chain %d: private key is required", i)
		}
		if chain.SyncAVS == "" {
			return fmt.Errorf("chain %d: SyncAVS address is required", i)
		}
		if chain.PoolManager == "" {
			return fmt.Errorf("chain %d: PoolManager address is required", i)
		}
	}

	if config.EigenLayer.RegistryCoordinator == "" {
		return fmt.Errorf("EigenLayer registry coordinator address is required")
	}

	if config.Across.SpokePool == "" {
		return fmt.Errorf("Across spoke pool address is required")
	}

	return nil
}

// GetDatabaseDSN returns the database connection string
func (c *Config) GetDatabaseDSN() string {
	password := c.Database.Password
	if password == "" {
		password = os.Getenv("DATABASE_PASSWORD")
	}

	return fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		c.Database.Host,
		c.Database.Port,
		c.Database.User,
		password,
		c.Database.DBName,
		c.Database.SSLMode,
	)
}

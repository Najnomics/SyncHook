package logger

import (
	"io"
	"os"
	"strings"

	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"
)

// Config holds logger configuration
type Config struct {
	Level  string `mapstructure:"level"`
	Format string `mapstructure:"format"`
	Output string `mapstructure:"output"`
}

// New creates a new logger instance
func New(cfg Config) (*logrus.Logger, error) {
	log := logrus.New()

	// Set log level
	level, err := logrus.ParseLevel(cfg.Level)
	if err != nil {
		return nil, err
	}
	log.SetLevel(level)

	// Set log format
	switch strings.ToLower(cfg.Format) {
	case "json":
		log.SetFormatter(&logrus.JSONFormatter{
			TimestampFormat: "2006-01-02T15:04:05.000Z07:00",
		})
	case "text":
		log.SetFormatter(&logrus.TextFormatter{
			FullTimestamp:   true,
			TimestampFormat: "2006-01-02 15:04:05",
		})
	default:
		log.SetFormatter(&logrus.JSONFormatter{
			TimestampFormat: "2006-01-02T15:04:05.000Z07:00",
		})
	}

	// Set output
	switch strings.ToLower(cfg.Output) {
	case "stdout":
		log.SetOutput(os.Stdout)
	case "stderr":
		log.SetOutput(os.Stderr)
	case "file":
		// For file output, you would typically configure a file path
		// This is a simplified version
		log.SetOutput(os.Stdout)
	default:
		log.SetOutput(os.Stdout)
	}

	return log, nil
}

// NewFromViper creates a logger from viper configuration
func NewFromViper(v *viper.Viper) (*logrus.Logger, error) {
	var cfg Config
	if err := v.UnmarshalKey("log", &cfg); err != nil {
		return nil, err
	}
	return New(cfg)
}

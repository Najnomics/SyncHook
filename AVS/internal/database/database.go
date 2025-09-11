package database

import (
	"fmt"
	"time"

	"github.com/sirupsen/logrus"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Database represents the database connection
type Database struct {
	DB     *gorm.DB
	logger *logrus.Logger
}

// New creates a new database connection
func New(dsn string, logger *logrus.Logger) (*Database, error) {
	// Configure GORM logger
	gormLogger := logger.New()
	gormLogger.SetLevel(logrus.DebugLevel)

	// Connect to database
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	// Configure connection pool
	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("failed to get underlying sql.DB: %w", err)
	}

	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetMaxOpenConns(100)
	sqlDB.SetConnMaxLifetime(time.Hour)

	return &Database{
		DB:     db,
		logger: logger,
	}, nil
}

// Start starts the database connection
func (d *Database) Start() error {
	d.logger.Info("Starting database connection")
	
	// Auto-migrate tables
	if err := d.autoMigrate(); err != nil {
		return fmt.Errorf("failed to auto-migrate: %w", err)
	}

	return nil
}

// Stop stops the database connection
func (d *Database) Stop() error {
	d.logger.Info("Stopping database connection")
	
	sqlDB, err := d.DB.DB()
	if err != nil {
		return err
	}
	
	return sqlDB.Close()
}

// autoMigrate runs database migrations
func (d *Database) autoMigrate() error {
	// This is where you would define your models and run migrations
	// For now, we'll just return nil as this is a simplified implementation
	
	d.logger.Info("Running database migrations")
	return nil
}

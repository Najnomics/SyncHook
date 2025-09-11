package monitoring

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/Layr-Labs/eigensdk-go/logging"
)

// AlertManager manages alerts for the SyncHook operator
type AlertManager struct {
	logger    logging.Logger
	alerts    map[string]*Alert
	alertsMutex sync.RWMutex
	
	// Alert channels
	alertChan    chan *Alert
	resolveChan  chan string
	
	// Alert thresholds
	thresholds   AlertThresholds
	
	// Alert handlers
	handlers     []AlertHandler
}

// Alert represents an alert
type Alert struct {
	ID          string                 `json:"id"`
	Type        string                 `json:"type"`
	Severity    string                 `json:"severity"` // "low", "medium", "high", "critical"
	Message     string                 `json:"message"`
	Timestamp   uint64                 `json:"timestamp"`
	Resolved    bool                   `json:"resolved"`
	ResolvedAt  uint64                 `json:"resolvedAt"`
	Metadata    map[string]interface{} `json:"metadata"`
	Source      string                 `json:"source"`
	Tags        []string               `json:"tags"`
}

// AlertThresholds represents alert thresholds
type AlertThresholds struct {
	PriceDeviation      float64 `json:"price_deviation"`
	LiquidityImbalance  float64 `json:"liquidity_imbalance"`
	ResponseTime        int     `json:"response_time"`
	ErrorRate           float64 `json:"error_rate"`
	Uptime              float64 `json:"uptime"`
	MemoryUsage         float64 `json:"memory_usage"`
	CPUUsage            float64 `json:"cpu_usage"`
}

// AlertHandler represents an alert handler
type AlertHandler interface {
	HandleAlert(alert *Alert) error
	HandleAlertResolved(alertID string) error
}

// NewAlertManager creates a new alert manager
func NewAlertManager(logger logging.Logger, thresholds AlertThresholds) *AlertManager {
	return &AlertManager{
		logger:      logger,
		alerts:      make(map[string]*Alert),
		alertChan:   make(chan *Alert, 100),
		resolveChan: make(chan string, 100),
		thresholds:  thresholds,
		handlers:    make([]AlertHandler, 0),
	}
}

// Start starts the alert manager
func (am *AlertManager) Start(ctx context.Context) {
	am.logger.Info("Starting alert manager")
	
	// Start alert processing
	go am.processAlerts(ctx)
	
	// Start alert cleanup
	go am.cleanupAlerts(ctx)
	
	am.logger.Info("Alert manager started")
}

// AddHandler adds an alert handler
func (am *AlertManager) AddHandler(handler AlertHandler) {
	am.handlers = append(am.handlers, handler)
}

// CreateAlert creates a new alert
func (am *AlertManager) CreateAlert(alertType, severity, message, source string, metadata map[string]interface{}, tags []string) string {
	alertID := fmt.Sprintf("%s_%d", alertType, time.Now().UnixNano())
	
	alert := &Alert{
		ID:        alertID,
		Type:      alertType,
		Severity:  severity,
		Message:   message,
		Timestamp: uint64(time.Now().Unix()),
		Resolved:  false,
		Metadata:  metadata,
		Source:    source,
		Tags:      tags,
	}
	
	am.alertsMutex.Lock()
	am.alerts[alertID] = alert
	am.alertsMutex.Unlock()
	
	// Send to alert channel
	select {
	case am.alertChan <- alert:
	default:
		am.logger.Warn("Alert channel full, dropping alert", "alertID", alertID)
	}
	
	am.logger.Warn("Alert created",
		"alertID", alertID,
		"type", alertType,
		"severity", severity,
		"message", message,
		"source", source,
	)
	
	return alertID
}

// ResolveAlert resolves an alert
func (am *AlertManager) ResolveAlert(alertID string) error {
	am.alertsMutex.Lock()
	defer am.alertsMutex.Unlock()
	
	alert, exists := am.alerts[alertID]
	if !exists {
		return fmt.Errorf("alert not found: %s", alertID)
	}
	
	if alert.Resolved {
		return fmt.Errorf("alert already resolved: %s", alertID)
	}
	
	alert.Resolved = true
	alert.ResolvedAt = uint64(time.Now().Unix())
	
	// Send to resolve channel
	select {
	case am.resolveChan <- alertID:
	default:
		am.logger.Warn("Resolve channel full, dropping resolve", "alertID", alertID)
	}
	
	am.logger.Info("Alert resolved", "alertID", alertID)
	return nil
}

// GetAlert gets an alert by ID
func (am *AlertManager) GetAlert(alertID string) (*Alert, error) {
	am.alertsMutex.RLock()
	defer am.alertsMutex.RUnlock()
	
	alert, exists := am.alerts[alertID]
	if !exists {
		return nil, fmt.Errorf("alert not found: %s", alertID)
	}
	
	return alert, nil
}

// GetAlerts gets alerts with optional filtering
func (am *AlertManager) GetAlerts(severity string, resolved bool, limit int) []*Alert {
	am.alertsMutex.RLock()
	defer am.alertsMutex.RUnlock()
	
	var filteredAlerts []*Alert
	count := 0
	
	for _, alert := range am.alerts {
		if limit > 0 && count >= limit {
			break
		}
		
		if severity != "" && alert.Severity != severity {
			continue
		}
		
		if alert.Resolved != resolved {
			continue
		}
		
		filteredAlerts = append(filteredAlerts, alert)
		count++
	}
	
	return filteredAlerts
}

// GetActiveAlerts gets all active alerts
func (am *AlertManager) GetActiveAlerts() []*Alert {
	return am.GetAlerts("", false, 0)
}

// GetCriticalAlerts gets all critical alerts
func (am *AlertManager) GetCriticalAlerts() []*Alert {
	return am.GetAlerts("critical", false, 0)
}

// GetAlertStats gets alert statistics
func (am *AlertManager) GetAlertStats() map[string]interface{} {
	am.alertsMutex.RLock()
	defer am.alertsMutex.RUnlock()
	
	stats := map[string]interface{}{
		"total":     0,
		"active":    0,
		"resolved":  0,
		"critical":  0,
		"high":      0,
		"medium":    0,
		"low":       0,
	}
	
	for _, alert := range am.alerts {
		stats["total"] = stats["total"].(int) + 1
		
		if alert.Resolved {
			stats["resolved"] = stats["resolved"].(int) + 1
		} else {
			stats["active"] = stats["active"].(int) + 1
		}
		
		switch alert.Severity {
		case "critical":
			stats["critical"] = stats["critical"].(int) + 1
		case "high":
			stats["high"] = stats["high"].(int) + 1
		case "medium":
			stats["medium"] = stats["medium"].(int) + 1
		case "low":
			stats["low"] = stats["low"].(int) + 1
		}
	}
	
	return stats
}

// processAlerts processes incoming alerts
func (am *AlertManager) processAlerts(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case alert := <-am.alertChan:
			am.handleAlert(alert)
		case alertID := <-am.resolveChan:
			am.handleAlertResolved(alertID)
		}
	}
}

// handleAlert handles a new alert
func (am *AlertManager) handleAlert(alert *Alert) {
	am.logger.Info("Processing alert",
		"alertID", alert.ID,
		"type", alert.Type,
		"severity", alert.Severity,
		"message", alert.Message,
	)
	
	// Call all handlers
	for _, handler := range am.handlers {
		if err := handler.HandleAlert(alert); err != nil {
			am.logger.Error("Alert handler failed",
				"alertID", alert.ID,
				"error", err,
			)
		}
	}
}

// handleAlertResolved handles an alert resolution
func (am *AlertManager) handleAlertResolved(alertID string) {
	am.logger.Info("Processing alert resolution", "alertID", alertID)
	
	// Call all handlers
	for _, handler := range am.handlers {
		if err := handler.HandleAlertResolved(alertID); err != nil {
			am.logger.Error("Alert resolution handler failed",
				"alertID", alertID,
				"error", err,
			)
		}
	}
}

// cleanupAlerts cleans up old resolved alerts
func (am *AlertManager) cleanupAlerts(ctx context.Context) {
	ticker := time.NewTicker(1 * time.Hour) // Clean up every hour
	defer ticker.Stop()
	
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			am.cleanupOldAlerts()
		}
	}
}

// cleanupOldAlerts removes old resolved alerts
func (am *AlertManager) cleanupOldAlerts() {
	am.alertsMutex.Lock()
	defer am.alertsMutex.Unlock()
	
	now := uint64(time.Now().Unix())
	cutoff := now - (7 * 24 * 60 * 60) // 7 days ago
	
	var toDelete []string
	for alertID, alert := range am.alerts {
		if alert.Resolved && alert.ResolvedAt < cutoff {
			toDelete = append(toDelete, alertID)
		}
	}
	
	for _, alertID := range toDelete {
		delete(am.alerts, alertID)
	}
	
	if len(toDelete) > 0 {
		am.logger.Info("Cleaned up old alerts", "count", len(toDelete))
	}
}

// CheckThresholds checks if any thresholds are exceeded
func (am *AlertManager) CheckThresholds(metrics map[string]float64) {
	// Check price deviation
	if priceDeviation, exists := metrics["price_deviation"]; exists {
		if priceDeviation > am.thresholds.PriceDeviation {
			am.CreateAlert("price_deviation", "high",
				fmt.Sprintf("Price deviation exceeded threshold: %.2f%% > %.2f%%", 
					priceDeviation*100, am.thresholds.PriceDeviation*100),
				"monitoring", map[string]interface{}{
					"price_deviation": priceDeviation,
					"threshold":       am.thresholds.PriceDeviation,
				}, []string{"price", "deviation"})
		}
	}
	
	// Check liquidity imbalance
	if liquidityImbalance, exists := metrics["liquidity_imbalance"]; exists {
		if liquidityImbalance > am.thresholds.LiquidityImbalance {
			am.CreateAlert("liquidity_imbalance", "high",
				fmt.Sprintf("Liquidity imbalance exceeded threshold: %.2f%% > %.2f%%", 
					liquidityImbalance*100, am.thresholds.LiquidityImbalance*100),
				"monitoring", map[string]interface{}{
					"liquidity_imbalance": liquidityImbalance,
					"threshold":           am.thresholds.LiquidityImbalance,
				}, []string{"liquidity", "imbalance"})
		}
	}
	
	// Check response time
	if responseTime, exists := metrics["response_time"]; exists {
		if responseTime > float64(am.thresholds.ResponseTime) {
			am.CreateAlert("response_time", "medium",
				fmt.Sprintf("Response time exceeded threshold: %.2fs > %ds", 
					responseTime, am.thresholds.ResponseTime),
				"monitoring", map[string]interface{}{
					"response_time": responseTime,
					"threshold":     am.thresholds.ResponseTime,
				}, []string{"response", "time"})
		}
	}
	
	// Check error rate
	if errorRate, exists := metrics["error_rate"]; exists {
		if errorRate > am.thresholds.ErrorRate {
			am.CreateAlert("error_rate", "high",
				fmt.Sprintf("Error rate exceeded threshold: %.2f%% > %.2f%%", 
					errorRate*100, am.thresholds.ErrorRate*100),
				"monitoring", map[string]interface{}{
					"error_rate": errorRate,
					"threshold":  am.thresholds.ErrorRate,
				}, []string{"error", "rate"})
		}
	}
	
	// Check uptime
	if uptime, exists := metrics["uptime"]; exists {
		if uptime < am.thresholds.Uptime {
			am.CreateAlert("uptime", "critical",
				fmt.Sprintf("Uptime below threshold: %.2f%% < %.2f%%", 
					uptime*100, am.thresholds.Uptime*100),
				"monitoring", map[string]interface{}{
					"uptime":   uptime,
					"threshold": am.thresholds.Uptime,
				}, []string{"uptime"})
		}
	}
	
	// Check memory usage
	if memoryUsage, exists := metrics["memory_usage"]; exists {
		if memoryUsage > am.thresholds.MemoryUsage {
			am.CreateAlert("memory_usage", "medium",
				fmt.Sprintf("Memory usage exceeded threshold: %.2f%% > %.2f%%", 
					memoryUsage*100, am.thresholds.MemoryUsage*100),
				"monitoring", map[string]interface{}{
					"memory_usage": memoryUsage,
					"threshold":    am.thresholds.MemoryUsage,
				}, []string{"memory", "usage"})
		}
	}
	
	// Check CPU usage
	if cpuUsage, exists := metrics["cpu_usage"]; exists {
		if cpuUsage > am.thresholds.CPUUsage {
			am.CreateAlert("cpu_usage", "medium",
				fmt.Sprintf("CPU usage exceeded threshold: %.2f%% > %.2f%%", 
					cpuUsage*100, am.thresholds.CPUUsage*100),
				"monitoring", map[string]interface{}{
					"cpu_usage": cpuUsage,
					"threshold": am.thresholds.CPUUsage,
				}, []string{"cpu", "usage"})
		}
	}
}

// GetDefaultThresholds returns default alert thresholds
func GetDefaultThresholds() AlertThresholds {
	return AlertThresholds{
		PriceDeviation:     0.1,  // 10%
		LiquidityImbalance: 0.2,  // 20%
		ResponseTime:       30,   // 30 seconds
		ErrorRate:          0.05, // 5%
		Uptime:             0.99, // 99%
		MemoryUsage:        0.8,  // 80%
		CPUUsage:           0.8,  // 80%
	}
}

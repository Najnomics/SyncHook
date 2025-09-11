package monitoring

import (
	"context"
	"fmt"
	"math/big"
	"sync"
	"time"

	"github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

type Monitor struct {
	logger logging.Logger
	
	// Metrics
	poolStatesTotal     prometheus.Gauge
	rebalancingRequests prometheus.Counter
	rebalancingSuccess  prometheus.Counter
	rebalancingFailures prometheus.Counter
	stateUpdateLatency  prometheus.Histogram
	operatorUptime      prometheus.Gauge
	
	// Alerts
	alerts      map[string]*Alert
	alertsMutex sync.RWMutex
	
	// Performance tracking
	performance *PerformanceTracker
}


type PerformanceTracker struct {
	StateUpdates     int64     `json:"stateUpdates"`
	RebalancingOps   int64     `json:"rebalancingOps"`
	SuccessfulOps    int64     `json:"successfulOps"`
	FailedOps        int64     `json:"failedOps"`
	AverageLatency   float64   `json:"averageLatency"`
	Uptime           float64   `json:"uptime"`
	LastUpdate       time.Time `json:"lastUpdate"`
}

type MetricsConfig struct {
	EnableMetrics bool   `json:"enableMetrics"`
	Port          string `json:"port"`
	Path          string `json:"path"`
}

func NewMonitor(logger logging.Logger) *Monitor {
	// Initialize Prometheus metrics
	poolStatesTotal := promauto.NewGauge(prometheus.GaugeOpts{
		Name: "synchook_pool_states_total",
		Help: "Total number of pool states being tracked",
	})
	
	rebalancingRequests := promauto.NewCounter(prometheus.CounterOpts{
		Name: "synchook_rebalancing_requests_total",
		Help: "Total number of rebalancing requests",
	})
	
	rebalancingSuccess := promauto.NewCounter(prometheus.CounterOpts{
		Name: "synchook_rebalancing_success_total",
		Help: "Total number of successful rebalancing operations",
	})
	
	rebalancingFailures := promauto.NewCounter(prometheus.CounterOpts{
		Name: "synchook_rebalancing_failures_total",
		Help: "Total number of failed rebalancing operations",
	})
	
	stateUpdateLatency := promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "synchook_state_update_latency_seconds",
		Help:    "Latency of state updates in seconds",
		Buckets: prometheus.DefBuckets,
	})
	
	operatorUptime := promauto.NewGauge(prometheus.GaugeOpts{
		Name: "synchook_operator_uptime_seconds",
		Help: "Operator uptime in seconds",
	})

	return &Monitor{
		logger:             logger,
		poolStatesTotal:    poolStatesTotal,
		rebalancingRequests: rebalancingRequests,
		rebalancingSuccess:  rebalancingSuccess,
		rebalancingFailures: rebalancingFailures,
		stateUpdateLatency:  stateUpdateLatency,
		operatorUptime:      operatorUptime,
		alerts:             make(map[string]*Alert),
		performance:        &PerformanceTracker{},
	}
}

func (m *Monitor) Start(ctx context.Context) {
	m.logger.Info("Starting SyncHook monitor")
	
	// Start uptime tracking
	go m.trackUptime(ctx)
	
	// Start alert processing
	go m.processAlerts(ctx)
	
	// Start performance monitoring
	go m.monitorPerformance(ctx)
	
	m.logger.Info("SyncHook monitor started successfully")
}

func (m *Monitor) RecordStateUpdate(poolID string, latency time.Duration) {
	m.logger.Debug("Recording state update",
		"poolID", poolID,
		"latency", latency,
	)
	
	m.stateUpdateLatency.Observe(latency.Seconds())
	m.performance.StateUpdates++
	m.performance.LastUpdate = time.Now()
}

func (m *Monitor) RecordRebalancingRequest(poolID string, amount *big.Int) {
	m.logger.Info("Recording rebalancing request",
		"poolID", poolID,
		"amount", amount.String(),
	)
	
	m.rebalancingRequests.Inc()
	m.performance.RebalancingOps++
}

func (m *Monitor) RecordRebalancingSuccess(poolID string, amount *big.Int, cost *big.Int) {
	m.logger.Info("Recording rebalancing success",
		"poolID", poolID,
		"amount", amount.String(),
		"cost", cost.String(),
	)
	
	m.rebalancingSuccess.Inc()
	m.performance.SuccessfulOps++
}

func (m *Monitor) RecordRebalancingFailure(poolID string, amount *big.Int, error string) {
	m.logger.Error("Recording rebalancing failure",
		"poolID", poolID,
		"amount", amount.String(),
		"error", error,
	)
	
	m.rebalancingFailures.Inc()
	m.performance.FailedOps++
	
	// Create alert for rebalancing failure
	m.CreateAlert("rebalancing_failure", "high", 
		fmt.Sprintf("Rebalancing failed for pool %s: %s", poolID, error),
		map[string]interface{}{
			"poolID": poolID,
			"amount": amount.String(),
			"error":  error,
		})
}

func (m *Monitor) UpdatePoolStatesCount(count int) {
	m.poolStatesTotal.Set(float64(count))
}

func (m *Monitor) CreateAlert(alertType, severity, message string, metadata map[string]interface{}) string {
	alertID := fmt.Sprintf("%s_%d", alertType, time.Now().UnixNano())
	
	alert := &Alert{
		ID:        alertID,
		Type:      alertType,
		Severity:  severity,
		Message:   message,
		Timestamp: uint64(time.Now().Unix()),
		Resolved:  false,
		Metadata:  metadata,
	}
	
	m.alertsMutex.Lock()
	m.alerts[alertID] = alert
	m.alertsMutex.Unlock()
	
	m.logger.Warn("Alert created",
		"alertID", alertID,
		"type", alertType,
		"severity", severity,
		"message", message,
	)
	
	return alertID
}

func (m *Monitor) ResolveAlert(alertID string) error {
	m.alertsMutex.Lock()
	defer m.alertsMutex.Unlock()
	
	alert, exists := m.alerts[alertID]
	if !exists {
		return fmt.Errorf("alert not found: %s", alertID)
	}
	
	alert.Resolved = true
	alert.ResolvedAt = uint64(time.Now().Unix())
	
	m.logger.Info("Alert resolved", "alertID", alertID)
	return nil
}

func (m *Monitor) GetAlerts(severity string, resolved bool) []*Alert {
	m.alertsMutex.RLock()
	defer m.alertsMutex.RUnlock()
	
	var filteredAlerts []*Alert
	for _, alert := range m.alerts {
		if severity != "" && alert.Severity != severity {
			continue
		}
		if alert.Resolved != resolved {
			continue
		}
		filteredAlerts = append(filteredAlerts, alert)
	}
	
	return filteredAlerts
}

func (m *Monitor) GetPerformanceMetrics() *PerformanceTracker {
	return m.performance
}

func (m *Monitor) trackUptime(ctx context.Context) {
	startTime := time.Now()
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()
	
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			uptime := time.Since(startTime).Seconds()
			m.operatorUptime.Set(uptime)
			m.performance.Uptime = uptime
		}
	}
}

func (m *Monitor) processAlerts(ctx context.Context) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			m.processExpiredAlerts()
			m.processCriticalAlerts()
		}
	}
}

func (m *Monitor) processExpiredAlerts() {
	m.alertsMutex.Lock()
	defer m.alertsMutex.Unlock()
	
	now := uint64(time.Now().Unix())
	expiredThreshold := uint64(24 * 60 * 60) // 24 hours
	
	for alertID, alert := range m.alerts {
		if !alert.Resolved && (now-alert.Timestamp) > expiredThreshold {
			alert.Resolved = true
			alert.ResolvedAt = now
			m.logger.Info("Alert expired and auto-resolved", "alertID", alertID)
		}
	}
}

func (m *Monitor) processCriticalAlerts() {
	criticalAlerts := m.GetAlerts("critical", false)
	
	for _, alert := range criticalAlerts {
		m.logger.Error("Critical alert active",
			"alertID", alert.ID,
			"message", alert.Message,
			"timestamp", alert.Timestamp,
		)
		
		// TODO: Send notifications (email, Slack, etc.)
		// This would integrate with external notification services
	}
}

func (m *Monitor) monitorPerformance(ctx context.Context) {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()
	
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			m.calculatePerformanceMetrics()
		}
	}
}

func (m *Monitor) calculatePerformanceMetrics() {
	// Calculate success rate
	totalOps := m.performance.SuccessfulOps + m.performance.FailedOps
	if totalOps > 0 {
		successRate := float64(m.performance.SuccessfulOps) / float64(totalOps)
		m.logger.Debug("Performance metrics calculated",
			"successRate", successRate,
			"totalOps", totalOps,
			"stateUpdates", m.performance.StateUpdates,
		)
	}
	
	// Reset counters periodically
	if m.performance.StateUpdates > 1000 {
		m.performance.StateUpdates = 0
		m.performance.RebalancingOps = 0
		m.performance.SuccessfulOps = 0
		m.performance.FailedOps = 0
	}
}

// Health check endpoint
func (m *Monitor) HealthCheck() map[string]interface{} {
	now := time.Now()
	
	// Check if operator is responsive
	lastUpdate := m.performance.LastUpdate
	timeSinceUpdate := now.Sub(lastUpdate)
	
	health := map[string]interface{}{
		"status":           "healthy",
		"uptime":           m.performance.Uptime,
		"lastUpdate":       lastUpdate,
		"timeSinceUpdate":  timeSinceUpdate.String(),
		"stateUpdates":     m.performance.StateUpdates,
		"rebalancingOps":   m.performance.RebalancingOps,
		"successfulOps":    m.performance.SuccessfulOps,
		"failedOps":        m.performance.FailedOps,
		"activeAlerts":     len(m.GetAlerts("", false)),
		"criticalAlerts":   len(m.GetAlerts("critical", false)),
	}
	
	// Mark as unhealthy if no updates in 5 minutes
	if timeSinceUpdate > 5*time.Minute {
		health["status"] = "unhealthy"
		health["reason"] = "No updates in 5 minutes"
	}
	
	return health
}

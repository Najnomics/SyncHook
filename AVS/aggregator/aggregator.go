package aggregator

import (
	"context"
	"fmt"
	"math/big"
	"sync"
	"time"

	"github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/ethereum/go-ethereum/common"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

type SyncHookAggregator struct {
	config    Config
	logger    logging.Logger
	
	// Metrics
	tasksTotal        prometheus.Counter
	tasksCompleted    prometheus.Counter
	tasksFailed       prometheus.Counter
	stateUpdates      prometheus.Counter
	rebalancingOps    prometheus.Counter
	
	// State management
	poolStates        map[string]*GlobalPoolState
	poolStatesMutex   sync.RWMutex
	
	// Task management
	tasks             map[uint32]*SyncHookTask
	tasksMutex        sync.RWMutex
	
	// Control
	ctx    context.Context
	cancel context.CancelFunc
}

type Config struct {
	ServerIpPortAddress         string  `json:"server_ip_port_address"`
	EnableGrpc                  bool    `json:"enable_grpc"`
	EnableHttp                  bool    `json:"enable_http"`
	HttpPort                    int     `json:"http_port"`
	RegistryCoordinatorAddress  string  `json:"registry_coordinator_address"`
	OperatorStateRetrieverAddress string `json:"operator_state_retriever_address"`
	EthRpcUrl                   string  `json:"eth_rpc_url"`
	EthWsUrl                    string  `json:"eth_ws_url"`
	SyncAVSAddress              string  `json:"sync_avs_address"`
	AcrossAddress               string  `json:"across_address"`
	TaskTimeout                 int     `json:"task_timeout"`
	MaxConcurrentTasks          int     `json:"max_concurrent_tasks"`
	TaskRetryAttempts           int     `json:"task_retry_attempts"`
	TaskRetryDelay              int     `json:"task_retry_delay"`
	StateUpdateInterval         int     `json:"state_update_interval"`
	StateValidationThreshold    float64 `json:"state_validation_threshold"`
	MaxStateAge                 int     `json:"max_state_age"`
	RebalancingEnabled          bool    `json:"rebalancing_enabled"`
	RebalancingThreshold        float64 `json:"rebalancing_threshold"`
	MaxRebalancingAmount        string  `json:"max_rebalancing_amount"`
	MinRebalancingAmount        string  `json:"min_rebalancing_amount"`
	RebalancingTimeout          int     `json:"rebalancing_timeout"`
	EnableMetrics               bool    `json:"enable_metrics"`
	MetricsPort                 int     `json:"metrics_port"`
	EnableHealthCheck           bool    `json:"enable_health_check"`
	HealthCheckInterval         int     `json:"health_check_interval"`
	LogLevel                    string  `json:"log_level"`
	LogFormat                   string  `json:"log_format"`
}

type SyncHookTask struct {
	TaskID           uint32         `json:"taskId"`
	TaskType         uint32         `json:"taskType"`
	ChainID          uint32         `json:"chainId"`
	PoolID           common.Hash    `json:"poolId"`
	Payload          []byte         `json:"payload"`
	Deadline         uint64         `json:"deadline"`
	Status           uint32         `json:"status"`
	CreatedAt        uint64         `json:"createdAt"`
	QuorumNumbers    []uint8        `json:"quorumNumbers"`
	QuorumThresholdPercentage uint32 `json:"quorumThresholdPercentage"`
	Responses        map[string]*SyncHookTaskResponse `json:"responses"`
	ConsensusReached bool           `json:"consensusReached"`
	Result           []byte         `json:"result"`
}

type SyncHookTaskResponse struct {
	OperatorAddress common.Address `json:"operatorAddress"`
	Response        []byte         `json:"response"`
	Signature       []byte         `json:"signature"`
	Timestamp       uint64         `json:"timestamp"`
	Valid           bool           `json:"valid"`
}

type GlobalPoolState struct {
	PoolID           string                 `json:"poolId"`
	TotalLiquidity   *big.Int               `json:"totalLiquidity"`
	AveragePrice     *big.Int               `json:"averagePrice"`
	ImbalanceScore   *big.Int               `json:"imbalanceScore"`
	LastUpdateBlock  uint64                 `json:"lastUpdateBlock"`
	ChainStates      map[uint32]*PoolState  `json:"chainStates"`
	LastUpdated      time.Time              `json:"lastUpdated"`
	ConsensusReached bool                   `json:"consensusReached"`
}

type PoolState struct {
	ChainID        uint32    `json:"chainId"`
	TotalLiquidity *big.Int  `json:"totalLiquidity"`
	Price          *big.Int  `json:"price"`
	Volume24h      *big.Int  `json:"volume24h"`
	Fees24h        *big.Int  `json:"fees24h"`
	Timestamp      uint64    `json:"timestamp"`
	BlockNumber    uint64    `json:"blockNumber"`
	LastUpdated    time.Time `json:"lastUpdated"`
}

func NewSyncHookAggregator(config Config, logger logging.Logger) (*SyncHookAggregator, error) {
	// Initialize Prometheus metrics
	tasksTotal := promauto.NewCounter(prometheus.CounterOpts{
		Name: "synchook_aggregator_tasks_total",
		Help: "Total number of tasks processed",
	})
	
	tasksCompleted := promauto.NewCounter(prometheus.CounterOpts{
		Name: "synchook_aggregator_tasks_completed_total",
		Help: "Total number of completed tasks",
	})
	
	tasksFailed := promauto.NewCounter(prometheus.CounterOpts{
		Name: "synchook_aggregator_tasks_failed_total",
		Help: "Total number of failed tasks",
	})
	
	stateUpdates := promauto.NewCounter(prometheus.CounterOpts{
		Name: "synchook_aggregator_state_updates_total",
		Help: "Total number of state updates",
	})
	
	rebalancingOps := promauto.NewCounter(prometheus.CounterOpts{
		Name: "synchook_aggregator_rebalancing_ops_total",
		Help: "Total number of rebalancing operations",
	})

	return &SyncHookAggregator{
		config:         config,
		logger:         logger,
		tasksTotal:     tasksTotal,
		tasksCompleted: tasksCompleted,
		tasksFailed:    tasksFailed,
		stateUpdates:   stateUpdates,
		rebalancingOps: rebalancingOps,
		poolStates:     make(map[string]*GlobalPoolState),
		tasks:          make(map[uint32]*SyncHookTask),
	}, nil
}

func (a *SyncHookAggregator) Start(ctx context.Context) error {
	a.ctx, a.cancel = context.WithCancel(ctx)

	a.logger.Info("Starting SyncHook aggregator")

	// Start task processing
	go a.taskProcessingLoop()

	// Start state aggregation
	go a.stateAggregationLoop()

	// Start rebalancing monitoring
	if a.config.RebalancingEnabled {
		go a.rebalancingLoop()
	}

	// Start health check
	if a.config.EnableHealthCheck {
		go a.healthCheckLoop()
	}

	a.logger.Info("SyncHook aggregator started successfully")

	// Wait for context cancellation
	<-a.ctx.Done()
	return nil
}

func (a *SyncHookAggregator) Stop() {
	if a.cancel != nil {
		a.cancel()
	}
}

func (a *SyncHookAggregator) taskProcessingLoop() {
	ticker := time.NewTicker(time.Duration(a.config.TaskTimeout) * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-a.ctx.Done():
			return
		case <-ticker.C:
			a.processTasks()
		}
	}
}

func (a *SyncHookAggregator) stateAggregationLoop() {
	ticker := time.NewTicker(time.Duration(a.config.StateUpdateInterval) * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-a.ctx.Done():
			return
		case <-ticker.C:
			a.aggregateStates()
		}
	}
}

func (a *SyncHookAggregator) rebalancingLoop() {
	ticker := time.NewTicker(60 * time.Second) // Check every minute
	defer ticker.Stop()

	for {
		select {
		case <-a.ctx.Done():
			return
		case <-ticker.C:
			a.checkRebalancingNeeds()
		}
	}
}

func (a *SyncHookAggregator) healthCheckLoop() {
	ticker := time.NewTicker(time.Duration(a.config.HealthCheckInterval) * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-a.ctx.Done():
			return
		case <-ticker.C:
			a.performHealthCheck()
		}
	}
}

func (a *SyncHookAggregator) processTasks() {
	a.tasksMutex.Lock()
	defer a.tasksMutex.Unlock()

	now := uint64(time.Now().Unix())
	
	for taskID, task := range a.tasks {
		// Check if task is expired
		if now > task.Deadline {
			a.logger.Warn("Task expired", "taskID", taskID, "deadline", task.Deadline)
			task.Status = 4 // Failed
			a.tasksFailed.Inc()
			continue
		}

		// Check if we have enough responses for consensus
		if len(task.Responses) >= int(task.QuorumThresholdPercentage) {
			a.processConsensus(task)
		}
	}
}

func (a *SyncHookAggregator) processConsensus(task *SyncHookTask) {
	if task.ConsensusReached {
		return
	}

	// Validate responses
	validResponses := 0
	for _, response := range task.Responses {
		if response.Valid {
			validResponses++
		}
	}

	// Check if we have enough valid responses
	if validResponses >= int(task.QuorumThresholdPercentage) {
		task.ConsensusReached = true
		task.Status = 3 // Completed
		a.tasksCompleted.Inc()
		
		a.logger.Info("Task consensus reached",
			"taskID", task.TaskID,
			"validResponses", validResponses,
			"required", task.QuorumThresholdPercentage,
		)
	}
}

func (a *SyncHookAggregator) aggregateStates() {
	a.poolStatesMutex.Lock()
	defer a.poolStatesMutex.Unlock()

	now := time.Now()
	
	for poolID, globalState := range a.poolStates {
		// Check if state is too old
		if now.Sub(globalState.LastUpdated).Seconds() > float64(a.config.MaxStateAge) {
			a.logger.Warn("Pool state too old, removing",
				"poolID", poolID,
				"lastUpdated", globalState.LastUpdated,
			)
			delete(a.poolStates, poolID)
			continue
		}

		// Aggregate chain states
		if err := a.aggregateChainStates(globalState); err != nil {
			a.logger.Error("Failed to aggregate chain states",
				"poolID", poolID,
				"error", err,
			)
			continue
		}

		a.stateUpdates.Inc()
	}
}

func (a *SyncHookAggregator) aggregateChainStates(globalState *GlobalPoolState) error {
	chainStates := globalState.ChainStates
	if len(chainStates) == 0 {
		return fmt.Errorf("no chain states available")
	}

	// Calculate total liquidity
	totalLiquidity := big.NewInt(0)
	for _, state := range chainStates {
		totalLiquidity.Add(totalLiquidity, state.TotalLiquidity)
	}
	globalState.TotalLiquidity = totalLiquidity

	// Calculate average price (weighted by liquidity)
	if err := a.calculateWeightedAveragePrice(chainStates, globalState); err != nil {
		return fmt.Errorf("failed to calculate weighted average price: %w", err)
	}

	// Calculate imbalance score
	if err := a.calculateImbalanceScore(chainStates, globalState); err != nil {
		return fmt.Errorf("failed to calculate imbalance score: %w", err)
	}

	// Update last update block
	var latestBlock uint64
	for _, state := range chainStates {
		if state.BlockNumber > latestBlock {
			latestBlock = state.BlockNumber
		}
	}
	globalState.LastUpdateBlock = latestBlock
	globalState.LastUpdated = time.Now()

	return nil
}

func (a *SyncHookAggregator) calculateWeightedAveragePrice(chainStates map[uint32]*PoolState, globalState *GlobalPoolState) error {
	if len(chainStates) == 0 {
		return fmt.Errorf("no chain states available")
	}

	totalWeight := big.NewInt(0)
	weightedPriceSum := big.NewInt(0)

	for _, state := range chainStates {
		weight := state.TotalLiquidity
		totalWeight.Add(totalWeight, weight)

		weightedPrice := new(big.Int).Mul(state.Price, weight)
		weightedPriceSum.Add(weightedPriceSum, weightedPrice)
	}

	if totalWeight.Cmp(big.NewInt(0)) == 0 {
		return fmt.Errorf("total weight is zero")
	}

	globalState.AveragePrice = new(big.Int).Div(weightedPriceSum, totalWeight)
	return nil
}

func (a *SyncHookAggregator) calculateImbalanceScore(chainStates map[uint32]*PoolState, globalState *GlobalPoolState) error {
	if len(chainStates) < 2 {
		globalState.ImbalanceScore = big.NewInt(0)
		return nil
	}

	// Calculate standard deviation of prices
	var prices []*big.Int
	for _, state := range chainStates {
		prices = append(prices, state.Price)
	}

	mean := globalState.AveragePrice
	variance := big.NewInt(0)
	for _, price := range prices {
		diff := new(big.Int).Sub(price, mean)
		diffSquared := new(big.Int).Mul(diff, diff)
		variance.Add(variance, diffSquared)
	}

	variance.Div(variance, big.NewInt(int64(len(prices))))
	globalState.ImbalanceScore = a.sqrt(variance)

	return nil
}

func (a *SyncHookAggregator) checkRebalancingNeeds() {
	a.poolStatesMutex.RLock()
	defer a.poolStatesMutex.RUnlock()

	for poolID, globalState := range a.poolStates {
		// Calculate current imbalance
		imbalance := a.calculateImbalance(globalState)
		imbalancePercent := a.calculateImbalancePercent(imbalance, globalState.TotalLiquidity)

		// Check if rebalancing is needed
		if imbalancePercent > a.config.RebalancingThreshold {
			a.logger.Info("Rebalancing needed",
				"poolID", poolID,
				"imbalancePercent", imbalancePercent,
				"threshold", a.config.RebalancingThreshold,
			)

			// TODO: Initiate rebalancing
			a.rebalancingOps.Inc()
		}
	}
}

func (a *SyncHookAggregator) calculateImbalance(globalState *GlobalPoolState) *big.Int {
	chainStates := globalState.ChainStates
	if len(chainStates) < 2 {
		return big.NewInt(0)
	}

	expectedPerChain := new(big.Int).Div(globalState.TotalLiquidity, big.NewInt(int64(len(chainStates))))
	totalDeviation := big.NewInt(0)

	for _, state := range chainStates {
		deviation := new(big.Int).Sub(state.TotalLiquidity, expectedPerChain)
		if deviation.Sign() < 0 {
			deviation.Neg(deviation)
		}
		totalDeviation.Add(totalDeviation, deviation)
	}

	return totalDeviation
}

func (a *SyncHookAggregator) calculateImbalancePercent(imbalance, totalLiquidity *big.Int) float64 {
	if totalLiquidity.Cmp(big.NewInt(0)) == 0 {
		return 0.0
	}

	percent := new(big.Int).Mul(imbalance, big.NewInt(100))
	percent.Div(percent, totalLiquidity)

	return float64(percent.Int64())
}

func (a *SyncHookAggregator) performHealthCheck() {
	// TODO: Implement health check logic
	// This would check various components and report status
	a.logger.Debug("Performing health check")
}

// Helper function for square root
func (a *SyncHookAggregator) sqrt(n *big.Int) *big.Int {
	if n.Cmp(big.NewInt(0)) <= 0 {
		return big.NewInt(0)
	}

	left := big.NewInt(0)
	right := new(big.Int).Set(n)
	result := big.NewInt(0)

	for left.Cmp(right) <= 0 {
		mid := new(big.Int).Add(left, right)
		mid.Div(mid, big.NewInt(2))

		midSquared := new(big.Int).Mul(mid, mid)
		if midSquared.Cmp(n) <= 0 {
			result.Set(mid)
			left.Add(mid, big.NewInt(1))
		} else {
			right.Sub(mid, big.NewInt(1))
		}
	}

	return result
}

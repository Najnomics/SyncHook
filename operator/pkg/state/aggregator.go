package state

import (
	"context"
	"fmt"
	"math/big"
	"sync"
	"time"

	"github.com/Layr-Labs/eigensdk-go/logging"
)

type Aggregator struct {
	logger    logging.Logger
	poolStates map[string]*GlobalPoolState
	mutex     sync.RWMutex
}

type GlobalPoolState struct {
	PoolID           string                 `json:"poolId"`
	TotalLiquidity   *big.Int               `json:"totalLiquidity"`
	AveragePrice     *big.Int               `json:"averagePrice"`
	ImbalanceScore   *big.Int               `json:"imbalanceScore"`
	LastUpdateBlock  uint64                 `json:"lastUpdateBlock"`
	ChainStates      map[uint32]*PoolState  `json:"chainStates"`
	LastUpdated      time.Time              `json:"lastUpdated"`
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

type AggregatedMetrics struct {
	TotalLiquidity     *big.Int `json:"totalLiquidity"`
	AveragePrice       *big.Int `json:"averagePrice"`
	PriceVariance      *big.Int `json:"priceVariance"`
	LiquidityImbalance *big.Int `json:"liquidityImbalance"`
	Volume24h          *big.Int `json:"volume24h"`
	Fees24h            *big.Int `json:"fees24h"`
	ActiveChains       uint32   `json:"activeChains"`
}

func NewAggregator(logger logging.Logger) *Aggregator {
	return &Aggregator{
		logger:     logger,
		poolStates: make(map[string]*GlobalPoolState),
	}
}

func (a *Aggregator) UpdatePoolState(ctx context.Context, poolID string, chainID uint32, state *PoolState) error {
	a.mutex.Lock()
	defer a.mutex.Unlock()

	a.logger.Debug("Updating pool state",
		"poolID", poolID,
		"chainID", chainID,
		"liquidity", state.TotalLiquidity.String(),
		"price", state.Price.String(),
	)

	// Get or create global pool state
	globalState, exists := a.poolStates[poolID]
	if !exists {
		globalState = &GlobalPoolState{
			PoolID:      poolID,
			ChainStates: make(map[uint32]*PoolState),
		}
		a.poolStates[poolID] = globalState
	}

	// Update chain state
	state.LastUpdated = time.Now()
	globalState.ChainStates[chainID] = state
	globalState.LastUpdated = time.Now()

	// Recalculate global metrics
	if err := a.recalculateGlobalMetrics(globalState); err != nil {
		return fmt.Errorf("failed to recalculate global metrics: %w", err)
	}

	a.logger.Info("Pool state updated successfully",
		"poolID", poolID,
		"chainID", chainID,
		"totalLiquidity", globalState.TotalLiquidity.String(),
		"averagePrice", globalState.AveragePrice.String(),
		"imbalanceScore", globalState.ImbalanceScore.String(),
	)

	return nil
}

func (a *Aggregator) GetGlobalPoolState(poolID string) (*GlobalPoolState, error) {
	a.mutex.RLock()
	defer a.mutex.RUnlock()

	globalState, exists := a.poolStates[poolID]
	if !exists {
		return nil, fmt.Errorf("pool state not found: %s", poolID)
	}

	return globalState, nil
}

func (a *Aggregator) GetAllPoolStates() map[string]*GlobalPoolState {
	a.mutex.RLock()
	defer a.mutex.RUnlock()

	// Return a copy to avoid race conditions
	result := make(map[string]*GlobalPoolState)
	for poolID, state := range a.poolStates {
		result[poolID] = state
	}

	return result
}

func (a *Aggregator) CalculateAggregatedMetrics(poolID string) (*AggregatedMetrics, error) {
	a.mutex.RLock()
	defer a.mutex.RUnlock()

	globalState, exists := a.poolStates[poolID]
	if !exists {
		return nil, fmt.Errorf("pool state not found: %s", poolID)
	}

	metrics := &AggregatedMetrics{
		TotalLiquidity: globalState.TotalLiquidity,
		AveragePrice:   globalState.AveragePrice,
		ActiveChains:   uint32(len(globalState.ChainStates)),
	}

	// Calculate price variance
	if err := a.calculatePriceVariance(globalState, metrics); err != nil {
		return nil, fmt.Errorf("failed to calculate price variance: %w", err)
	}

	// Calculate liquidity imbalance
	if err := a.calculateLiquidityImbalance(globalState, metrics); err != nil {
		return nil, fmt.Errorf("failed to calculate liquidity imbalance: %w", err)
	}

	// Calculate 24h metrics
	if err := a.calculate24hMetrics(globalState, metrics); err != nil {
		return nil, fmt.Errorf("failed to calculate 24h metrics: %w", err)
	}

	return metrics, nil
}

func (a *Aggregator) recalculateGlobalMetrics(globalState *GlobalPoolState) error {
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

	// Update last update block (use the latest block from any chain)
	var latestBlock uint64
	for _, state := range chainStates {
		if state.BlockNumber > latestBlock {
			latestBlock = state.BlockNumber
		}
	}
	globalState.LastUpdateBlock = latestBlock

	return nil
}

func (a *Aggregator) calculateWeightedAveragePrice(chainStates map[uint32]*PoolState, globalState *GlobalPoolState) error {
	if len(chainStates) == 0 {
		return fmt.Errorf("no chain states available")
	}

	// Calculate weighted average price
	totalWeight := big.NewInt(0)
	weightedPriceSum := big.NewInt(0)

	for _, state := range chainStates {
		// Use liquidity as weight
		weight := state.TotalLiquidity
		totalWeight.Add(totalWeight, weight)

		// Calculate weighted price contribution
		weightedPrice := new(big.Int).Mul(state.Price, weight)
		weightedPriceSum.Add(weightedPriceSum, weightedPrice)
	}

	if totalWeight.Cmp(big.NewInt(0)) == 0 {
		return fmt.Errorf("total weight is zero")
	}

	// Calculate average price
	globalState.AveragePrice = new(big.Int).Div(weightedPriceSum, totalWeight)

	return nil
}

func (a *Aggregator) calculateImbalanceScore(chainStates map[uint32]*PoolState, globalState *GlobalPoolState) error {
	if len(chainStates) < 2 {
		// No imbalance if only one chain
		globalState.ImbalanceScore = big.NewInt(0)
		return nil
	}

	// Calculate standard deviation of prices
	var prices []*big.Int
	for _, state := range chainStates {
		prices = append(prices, state.Price)
	}

	// Calculate mean
	mean := globalState.AveragePrice

	// Calculate variance
	variance := big.NewInt(0)
	for _, price := range prices {
		diff := new(big.Int).Sub(price, mean)
		diffSquared := new(big.Int).Mul(diff, diff)
		variance.Add(variance, diffSquared)
	}

	// Divide by number of chains
	variance.Div(variance, big.NewInt(int64(len(prices))))

	// Calculate standard deviation (sqrt of variance)
	globalState.ImbalanceScore = a.sqrt(variance)

	return nil
}

func (a *Aggregator) calculatePriceVariance(globalState *GlobalPoolState, metrics *AggregatedMetrics) error {
	chainStates := globalState.ChainStates
	if len(chainStates) < 2 {
		metrics.PriceVariance = big.NewInt(0)
		return nil
	}

	// Calculate variance
	variance := big.NewInt(0)
	for _, state := range chainStates {
		diff := new(big.Int).Sub(state.Price, globalState.AveragePrice)
		diffSquared := new(big.Int).Mul(diff, diff)
		variance.Add(variance, diffSquared)
	}

	// Divide by number of chains
	variance.Div(variance, big.NewInt(int64(len(chainStates))))
	metrics.PriceVariance = variance

	return nil
}

func (a *Aggregator) calculateLiquidityImbalance(globalState *GlobalPoolState, metrics *AggregatedMetrics) error {
	chainStates := globalState.ChainStates
	if len(chainStates) < 2 {
		metrics.LiquidityImbalance = big.NewInt(0)
		return nil
	}

	// Calculate expected liquidity per chain
	expectedLiquidityPerChain := new(big.Int).Div(globalState.TotalLiquidity, big.NewInt(int64(len(chainStates))))

	// Calculate total deviation from expected
	totalDeviation := big.NewInt(0)
	for _, state := range chainStates {
		deviation := new(big.Int).Sub(state.TotalLiquidity, expectedLiquidityPerChain)
		if deviation.Sign() < 0 {
			deviation.Neg(deviation)
		}
		totalDeviation.Add(totalDeviation, deviation)
	}

	// Calculate imbalance as percentage
	imbalance := new(big.Int).Mul(totalDeviation, big.NewInt(100))
	imbalance.Div(imbalance, globalState.TotalLiquidity)
	metrics.LiquidityImbalance = imbalance

	return nil
}

func (a *Aggregator) calculate24hMetrics(globalState *GlobalPoolState, metrics *AggregatedMetrics) error {
	chainStates := globalState.ChainStates

	// Sum up 24h metrics across all chains
	totalVolume24h := big.NewInt(0)
	totalFees24h := big.NewInt(0)

	for _, state := range chainStates {
		totalVolume24h.Add(totalVolume24h, state.Volume24h)
		totalFees24h.Add(totalFees24h, state.Fees24h)
	}

	metrics.Volume24h = totalVolume24h
	metrics.Fees24h = totalFees24h

	return nil
}

// Simple square root implementation for big.Int
func (a *Aggregator) sqrt(n *big.Int) *big.Int {
	if n.Cmp(big.NewInt(0)) <= 0 {
		return big.NewInt(0)
	}

	// Use binary search for square root
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

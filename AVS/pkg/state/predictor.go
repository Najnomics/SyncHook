package state

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"github.com/Layr-Labs/eigensdk-go/logging"
)

type Predictor struct {
	logger logging.Logger
}

type PredictionResult struct {
	PredictedPrice     *big.Int `json:"predictedPrice"`
	PredictedLiquidity *big.Int `json:"predictedLiquidity"`
	Confidence         float64  `json:"confidence"`
	TimeHorizon        uint64   `json:"timeHorizon"`
	Timestamp          uint64   `json:"timestamp"`
}

type PredictionModel struct {
	ModelType    string    `json:"modelType"`
	Parameters   map[string]interface{} `json:"parameters"`
	LastTrained  uint64    `json:"lastTrained"`
	Accuracy     float64   `json:"accuracy"`
}

type MarketTrend struct {
	Direction   string    `json:"direction"` // "up", "down", "sideways"
	Strength    float64   `json:"strength"`  // 0.0 to 1.0
	Confidence  float64   `json:"confidence"`
	Duration    uint64    `json:"duration"`  // seconds
}

func NewPredictor(logger logging.Logger) *Predictor {
	return &Predictor{
		logger: logger,
	}
}

func (p *Predictor) PredictPoolState(
	ctx context.Context,
	poolID string,
	globalState *GlobalPoolState,
	timeHorizon uint64,
) (*PredictionResult, error) {
	p.logger.Debug("Predicting pool state",
		"poolID", poolID,
		"timeHorizon", timeHorizon,
		"currentPrice", globalState.AveragePrice.String(),
		"currentLiquidity", globalState.TotalLiquidity.String(),
	)

	// Analyze historical trends
	trend, err := p.analyzeTrend(globalState)
	if err != nil {
		return nil, fmt.Errorf("failed to analyze trend: %w", err)
	}

	// Predict price based on trend
	predictedPrice, err := p.predictPrice(globalState, trend, timeHorizon)
	if err != nil {
		return nil, fmt.Errorf("failed to predict price: %w", err)
	}

	// Predict liquidity based on price prediction
	predictedLiquidity, err := p.predictLiquidity(globalState, predictedPrice, timeHorizon)
	if err != nil {
		return nil, fmt.Errorf("failed to predict liquidity: %w", err)
	}

	// Calculate confidence based on trend strength and data quality
	confidence := p.calculateConfidence(globalState, trend)

	result := &PredictionResult{
		PredictedPrice:     predictedPrice,
		PredictedLiquidity: predictedLiquidity,
		Confidence:         confidence,
		TimeHorizon:        timeHorizon,
		Timestamp:          uint64(time.Now().Unix()),
	}

	p.logger.Info("Pool state prediction completed",
		"poolID", poolID,
		"predictedPrice", predictedPrice.String(),
		"predictedLiquidity", predictedLiquidity.String(),
		"confidence", confidence,
		"trendDirection", trend.Direction,
		"trendStrength", trend.Strength,
	)

	return result, nil
}

func (p *Predictor) PredictRebalancingNeed(
	ctx context.Context,
	poolID string,
	globalState *GlobalPoolState,
	threshold float64,
) (bool, *big.Int, error) {
	p.logger.Debug("Predicting rebalancing need",
		"poolID", poolID,
		"threshold", threshold,
	)

	// Calculate current imbalance
	currentImbalance := p.calculateImbalance(globalState)

	// Predict future imbalance
	futureImbalance, err := p.predictImbalance(globalState, 300) // 5 minutes
	if err != nil {
		return false, nil, fmt.Errorf("failed to predict imbalance: %w", err)
	}

	// Check if imbalance exceeds threshold
	imbalancePercent := p.calculateImbalancePercent(futureImbalance, globalState.TotalLiquidity)
	needsRebalancing := imbalancePercent > threshold

	var rebalancingAmount *big.Int
	if needsRebalancing {
		rebalancingAmount = p.calculateRebalancingAmount(globalState, futureImbalance)
	}

	p.logger.Info("Rebalancing prediction completed",
		"poolID", poolID,
		"needsRebalancing", needsRebalancing,
		"currentImbalance", currentImbalance.String(),
		"futureImbalance", futureImbalance.String(),
		"imbalancePercent", imbalancePercent,
		"rebalancingAmount", rebalancingAmount.String(),
	)

	return needsRebalancing, rebalancingAmount, nil
}

func (p *Predictor) analyzeTrend(globalState *GlobalPoolState) (*MarketTrend, error) {
	chainStates := globalState.ChainStates
	if len(chainStates) < 2 {
		return &MarketTrend{
			Direction:  "sideways",
			Strength:   0.0,
			Confidence: 0.0,
		}, nil
	}

	// Calculate price variance across chains
	var prices []*big.Int
	for _, state := range chainStates {
		prices = append(prices, state.Price)
	}

	// Calculate trend direction and strength
	direction, strength, err := p.calculateTrendDirection(prices)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate trend direction: %w", err)
	}

	// Calculate confidence based on consistency across chains
	confidence := p.calculateTrendConfidence(chainStates)

	return &MarketTrend{
		Direction:  direction,
		Strength:   strength,
		Confidence: confidence,
		Duration:   300, // 5 minutes default
	}, nil
}

func (p *Predictor) calculateTrendDirection(prices []*big.Int) (string, float64, error) {
	if len(prices) < 2 {
		return "sideways", 0.0, nil
	}

	// Calculate average price
	total := big.NewInt(0)
	for _, price := range prices {
		total.Add(total, price)
	}
	avgPrice := new(big.Int).Div(total, big.NewInt(int64(len(prices))))

	// Calculate variance
	variance := big.NewInt(0)
	for _, price := range prices {
		diff := new(big.Int).Sub(price, avgPrice)
		diffSquared := new(big.Int).Mul(diff, diff)
		variance.Add(variance, diffSquared)
	}
	variance.Div(variance, big.NewInt(int64(len(prices))))

	// Calculate standard deviation
	stdDev := p.sqrt(variance)

	// Determine trend direction based on price distribution
	// If prices are clustered around average, trend is sideways
	// If prices show clear upward/downward pattern, trend is up/down

	// Simple heuristic: if std dev is low, trend is sideways
	// If std dev is high, check if there's a clear pattern
	threshold := new(big.Int).Div(avgPrice, big.NewInt(100)) // 1% threshold

	if stdDev.Cmp(threshold) < 0 {
		return "sideways", 0.0, nil
	}

	// Check for upward trend (more prices above average)
	aboveAvg := 0
	for _, price := range prices {
		if price.Cmp(avgPrice) > 0 {
			aboveAvg++
		}
	}

	strength := float64(aboveAvg) / float64(len(prices))
	if strength > 0.6 {
		return "up", strength, nil
	} else if strength < 0.4 {
		return "down", 1.0 - strength, nil
	}

	return "sideways", 0.0, nil
}

func (p *Predictor) calculateTrendConfidence(chainStates map[uint32]*PoolState) float64 {
	if len(chainStates) < 2 {
		return 0.0
	}

	// Calculate consistency across chains
	// Higher consistency = higher confidence
	var prices []*big.Int
	for _, state := range chainStates {
		prices = append(prices, state.Price)
	}

	// Calculate coefficient of variation
	avg := p.calculateAverage(prices)
	if avg.Cmp(big.NewInt(0)) == 0 {
		return 0.0
	}

	stdDev := p.calculateStandardDeviation(prices, avg)
	cv := new(big.Int).Mul(stdDev, big.NewInt(100))
	cv.Div(cv, avg)

	// Convert to confidence (lower CV = higher confidence)
	cvFloat := float64(cv.Int64())
	if cvFloat > 10 {
		return 0.0
	}
	if cvFloat > 5 {
		return 0.5
	}
	if cvFloat > 2 {
		return 0.8
	}
	return 1.0
}

func (p *Predictor) predictPrice(
	globalState *GlobalPoolState,
	trend *MarketTrend,
	timeHorizon uint64,
) (*big.Int, error) {
	currentPrice := globalState.AveragePrice
	if currentPrice.Cmp(big.NewInt(0)) == 0 {
		return big.NewInt(0), fmt.Errorf("no current price available")
	}

	// Simple linear prediction based on trend
	// In a real implementation, this would use more sophisticated models

	// Calculate price change based on trend strength and direction
	changePercent := p.calculatePriceChangePercent(trend, timeHorizon)
	
	// Apply change to current price
	change := new(big.Int).Mul(currentPrice, big.NewInt(int64(changePercent)))
	change.Div(change, big.NewInt(100))

	var predictedPrice *big.Int
	switch trend.Direction {
	case "up":
		predictedPrice = new(big.Int).Add(currentPrice, change)
	case "down":
		predictedPrice = new(big.Int).Sub(currentPrice, change)
	default: // sideways
		predictedPrice = new(big.Int).Set(currentPrice)
	}

	// Ensure price doesn't go negative
	if predictedPrice.Cmp(big.NewInt(0)) < 0 {
		predictedPrice = big.NewInt(1)
	}

	return predictedPrice, nil
}

func (p *Predictor) predictLiquidity(
	globalState *GlobalPoolState,
	predictedPrice *big.Int,
	timeHorizon uint64,
) (*big.Int, error) {
	currentLiquidity := globalState.TotalLiquidity
	if currentLiquidity.Cmp(big.NewInt(0)) == 0 {
		return big.NewInt(0), fmt.Errorf("no current liquidity available")
	}

	// Simple prediction: liquidity tends to follow price
	// Higher prices attract more liquidity, lower prices reduce liquidity
	currentPrice := globalState.AveragePrice
	if currentPrice.Cmp(big.NewInt(0)) == 0 {
		return currentLiquidity, nil
	}

	// Calculate price change percentage
	priceChange := new(big.Int).Sub(predictedPrice, currentPrice)
	priceChangePercent := new(big.Int).Mul(priceChange, big.NewInt(100))
	priceChangePercent.Div(priceChangePercent, currentPrice)

	// Apply liquidity change based on price change
	// This is a simplified model - real implementation would be more complex
	liquidityChange := new(big.Int).Mul(currentLiquidity, priceChangePercent)
	liquidityChange.Div(liquidityChange, big.NewInt(200)) // 0.5x multiplier

	predictedLiquidity := new(big.Int).Add(currentLiquidity, liquidityChange)

	// Ensure liquidity doesn't go negative
	if predictedLiquidity.Cmp(big.NewInt(0)) < 0 {
		predictedLiquidity = big.NewInt(1)
	}

	return predictedLiquidity, nil
}

func (p *Predictor) calculateImbalance(globalState *GlobalPoolState) *big.Int {
	chainStates := globalState.ChainStates
	if len(chainStates) < 2 {
		return big.NewInt(0)
	}

	// Calculate expected liquidity per chain
	expectedPerChain := new(big.Int).Div(globalState.TotalLiquidity, big.NewInt(int64(len(chainStates))))

	// Calculate total deviation
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

func (p *Predictor) predictImbalance(globalState *GlobalPoolState, timeHorizon uint64) (*big.Int, error) {
	// Simple prediction: assume current imbalance will continue
	// In a real implementation, this would use historical data and trends
	return p.calculateImbalance(globalState), nil
}

func (p *Predictor) calculateImbalancePercent(imbalance, totalLiquidity *big.Int) float64 {
	if totalLiquidity.Cmp(big.NewInt(0)) == 0 {
		return 0.0
	}

	// Calculate percentage
	percent := new(big.Int).Mul(imbalance, big.NewInt(100))
	percent.Div(percent, totalLiquidity)

	return float64(percent.Int64())
}

func (p *Predictor) calculateRebalancingAmount(globalState *GlobalPoolState, imbalance *big.Int) *big.Int {
	// Calculate rebalancing amount as a fraction of the imbalance
	// This is a simplified calculation
	rebalancingAmount := new(big.Int).Div(imbalance, big.NewInt(2)) // 50% of imbalance

	// Ensure minimum and maximum bounds
	minAmount := big.NewInt(1000000000000000000) // 1 token
	maxAmount := new(big.Int).Div(globalState.TotalLiquidity, big.NewInt(10)) // 10% of total liquidity

	if rebalancingAmount.Cmp(minAmount) < 0 {
		rebalancingAmount = minAmount
	}
	if rebalancingAmount.Cmp(maxAmount) > 0 {
		rebalancingAmount = maxAmount
	}

	return rebalancingAmount
}

func (p *Predictor) calculatePriceChangePercent(trend *MarketTrend, timeHorizon uint64) int64 {
	// Calculate price change based on trend strength and time horizon
	// This is a simplified model

	baseChange := int64(trend.Strength * 100) // Convert to percentage
	timeMultiplier := float64(timeHorizon) / 300.0 // Normalize to 5 minutes

	change := float64(baseChange) * timeMultiplier * trend.Confidence

	// Cap the change at 10%
	if change > 10 {
		change = 10
	}
	if change < -10 {
		change = -10
	}

	return int64(change)
}

func (p *Predictor) calculateConfidence(globalState *GlobalPoolState, trend *MarketTrend) float64 {
	// Base confidence on trend confidence and data quality
	baseConfidence := trend.Confidence

	// Adjust based on number of chains (more chains = higher confidence)
	chainCount := len(globalState.ChainStates)
	if chainCount >= 3 {
		baseConfidence *= 1.0
	} else if chainCount == 2 {
		baseConfidence *= 0.8
	} else {
		baseConfidence *= 0.5
	}

	// Adjust based on data freshness
	now := uint64(time.Now().Unix())
	age := now - globalState.LastUpdateBlock
	if age < 60 { // Less than 1 minute
		baseConfidence *= 1.0
	} else if age < 300 { // Less than 5 minutes
		baseConfidence *= 0.9
	} else if age < 600 { // Less than 10 minutes
		baseConfidence *= 0.8
	} else {
		baseConfidence *= 0.6
	}

	return baseConfidence
}

// Helper functions
func (p *Predictor) calculateAverage(values []*big.Int) *big.Int {
	if len(values) == 0 {
		return big.NewInt(0)
	}

	total := big.NewInt(0)
	for _, value := range values {
		total.Add(total, value)
	}

	return new(big.Int).Div(total, big.NewInt(int64(len(values))))
}

func (p *Predictor) calculateStandardDeviation(values []*big.Int, mean *big.Int) *big.Int {
	if len(values) == 0 {
		return big.NewInt(0)
	}

	variance := big.NewInt(0)
	for _, value := range values {
		diff := new(big.Int).Sub(value, mean)
		diffSquared := new(big.Int).Mul(diff, diff)
		variance.Add(variance, diffSquared)
	}

	variance.Div(variance, big.NewInt(int64(len(values))))
	return p.sqrt(variance)
}

func (p *Predictor) sqrt(n *big.Int) *big.Int {
	if n.Cmp(big.NewInt(0)) <= 0 {
		return big.NewInt(0)
	}

	// Simple binary search for square root
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

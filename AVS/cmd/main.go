package main

import (
	"context"
	"fmt"
	"time"

	"github.com/Layr-Labs/hourglass-monorepo/ponos/pkg/performer/server"
	performerV1 "github.com/Layr-Labs/protocol-apis/gen/protos/eigenlayer/hourglass/v1/performer"
	"go.uber.org/zap"
)

// This offchain binary is run by Operators running the SyncHook Executor. It contains
// the business logic of the AVS and performs work based on the tasks sent to it.
// The SyncHook Aggregator ingests tasks from the TaskMailbox and distributes work
// to Executors configured to run the AVS Performer. Performers execute the work and
// return the result to the Executor where the result is signed and returned to the
// Aggregator to place in the outbox once the signing threshold is met.

type SyncHookTaskWorker struct {
	logger *zap.Logger
}

func NewSyncHookTaskWorker(logger *zap.Logger) *SyncHookTaskWorker {
	return &SyncHookTaskWorker{
		logger: logger,
	}
}

func (tw *SyncHookTaskWorker) ValidateTask(t *performerV1.TaskRequest) error {
	tw.logger.Sugar().Infow("Validating SyncHook task",
		zap.Any("task", t),
	)

	// ------------------------------------------------------------------------
	// Implement SyncHook task validation logic here
	// ------------------------------------------------------------------------
	// This is where the Performer will validate the task request data.
	// For SyncHook, this could validate:
	// - Pool state update requests
	// - Rebalancing task parameters
	// - Cross-chain synchronization requests
	// - Task deadline and priority validation

	return nil
}

func (tw *SyncHookTaskWorker) HandleTask(t *performerV1.TaskRequest) (*performerV1.TaskResponse, error) {
	tw.logger.Sugar().Infow("Handling SyncHook task",
		zap.Any("task", t),
	)

	// ------------------------------------------------------------------------
	// Implement SyncHook AVS logic here
	// ------------------------------------------------------------------------
	// This is where the Performer will do the work and provide compute.
	// For SyncHook, this could include:
	// - Processing pool state updates
	// - Executing cross-chain rebalancing
	// - Validating liquidity synchronization
	// - Computing price arbitrage opportunities
	var resultBytes []byte
	return &performerV1.TaskResponse{
		TaskId: t.TaskId,
		Result: resultBytes,
	}, nil
}

func main() {
	ctx := context.Background()
	l, _ := zap.NewProduction()

	w := NewSyncHookTaskWorker(l)

	pp, err := server.NewPonosPerformerWithRpcServer(&server.PonosPerformerConfig{
		Port:    8080,
		Timeout: 5 * time.Second,
	}, w, l)
	if err != nil {
		panic(fmt.Errorf("failed to create SyncHook performer: %w", err))
	}

	if err := pp.Start(ctx); err != nil {
		panic(err)
	}
}

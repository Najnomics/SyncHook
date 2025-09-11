# SyncHook API Reference

## Overview

This document provides comprehensive API documentation for the SyncHook system, including smart contract interfaces, REST APIs, and GraphQL schemas.

## Table of Contents

1. [Smart Contract APIs](#smart-contract-apis)
2. [REST APIs](#rest-apis)
3. [GraphQL APIs](#graphql-apis)
4. [WebSocket APIs](#websocket-apis)
5. [Error Codes](#error-codes)
6. [Rate Limits](#rate-limits)

## Smart Contract APIs

### SyncHook Contract

#### Functions

##### `beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)`
- **Description**: Called before a swap operation to optimize parameters
- **Parameters**:
  - `sender`: Address initiating the swap
  - `key`: Pool key containing token0, token1, fee, tickSpacing, and hook
  - `params`: Swap parameters including zeroForOne, amountSpecified, sqrtPriceLimitX96
  - `hookData`: Additional data for the hook
- **Returns**: `(bytes4, BeforeSwapDelta, uint24)`
- **Events**: `SwapOptimized(address indexed pool, uint256 amountIn, uint256 amountOut)`

##### `afterSwap(address sender, PoolKey calldata key, SwapParams calldata params, BalanceDelta delta, bytes calldata hookData)`
- **Description**: Called after a swap operation to update global state
- **Parameters**:
  - `sender`: Address initiating the swap
  - `key`: Pool key
  - `params`: Swap parameters
  - `delta`: Balance changes from the swap
  - `hookData`: Additional data
- **Returns**: `(bytes4, int128)`
- **Events**: `SwapCompleted(address indexed pool, uint256 amountIn, uint256 amountOut)`

##### `beforeAddLiquidity(address sender, PoolKey calldata key, ModifyLiquidityParams calldata params, bytes calldata hookData)`
- **Description**: Called before adding liquidity to validate the operation
- **Parameters**:
  - `sender`: Address adding liquidity
  - `key`: Pool key
  - `params`: Liquidity modification parameters
  - `hookData`: Additional data
- **Returns**: `bytes4`
- **Events**: `LiquidityAdditionValidated(address indexed pool, uint256 amount)`

##### `afterAddLiquidity(address sender, PoolKey calldata key, ModifyLiquidityParams calldata params, BalanceDelta delta, BalanceDelta feesAccrued, bytes calldata hookData)`
- **Description**: Called after adding liquidity to update state
- **Parameters**:
  - `sender`: Address adding liquidity
  - `key`: Pool key
  - `params`: Liquidity modification parameters
  - `delta`: Balance changes
  - `feesAccrued`: Fees accrued
  - `hookData`: Additional data
- **Returns**: `bytes4`
- **Events**: `LiquidityAdded(address indexed pool, uint256 amount)`

##### `beforeRemoveLiquidity(address sender, PoolKey calldata key, ModifyLiquidityParams calldata params, bytes calldata hookData)`
- **Description**: Called before removing liquidity to ensure safe removal
- **Parameters**:
  - `sender`: Address removing liquidity
  - `key`: Pool key
  - `params`: Liquidity modification parameters
  - `hookData`: Additional data
- **Returns**: `bytes4`
- **Events**: `LiquidityRemovalValidated(address indexed pool, uint256 amount)`

##### `afterRemoveLiquidity(address sender, PoolKey calldata key, ModifyLiquidityParams calldata params, BalanceDelta delta, BalanceDelta feesAccrued, bytes calldata hookData)`
- **Description**: Called after removing liquidity to update state
- **Parameters**:
  - `sender`: Address removing liquidity
  - `key`: Pool key
  - `params`: Liquidity modification parameters
  - `delta`: Balance changes
  - `feesAccrued`: Fees accrued
  - `hookData`: Additional data
- **Returns**: `bytes4`
- **Events**: `LiquidityRemoved(address indexed pool, uint256 amount)`

##### `getHookPermissions()`
- **Description**: Returns the permissions for this hook
- **Returns**: `Hooks.Permissions` struct containing boolean flags for each hook function

### SyncAVS Contract

#### Functions

##### `submitStateUpdate(GlobalPoolState calldata globalState, bytes calldata signature)`
- **Description**: Submit a state update with operator signature
- **Parameters**:
  - `globalState`: Global pool state data
  - `signature`: Operator signature for validation
- **Returns**: `bool`
- **Events**: `StateUpdateSubmitted(address indexed operator, bytes32 indexed stateHash)`

##### `shouldTriggerRebalancing(Currency token0, Currency token1, uint24 fee, uint256 threshold)`
- **Description**: Check if rebalancing should be triggered
- **Parameters**:
  - `token0`: First token currency
  - `token1`: Second token currency
  - `fee`: Pool fee tier
  - `threshold`: Rebalancing threshold
- **Returns**: `(bool, uint256, uint256, uint256)`
- **Events**: `RebalancingTriggered(address indexed pool, uint256 imbalance)`

##### `getGlobalState(Currency token0, Currency token1, uint24 fee)`
- **Description**: Get aggregated global state for a pool
- **Parameters**:
  - `token0`: First token currency
  - `token1`: Second token currency
  - `fee`: Pool fee tier
- **Returns**: `(GlobalPoolState memory, uint256, uint256, uint256)`
- **Events**: None

##### `validateOperatorSignature(address operator, bytes32 messageHash, bytes calldata signature)`
- **Description**: Validate an operator's signature
- **Parameters**:
  - `operator`: Operator address
  - `messageHash`: Message hash to validate
  - `signature`: Signature to validate
- **Returns**: `bool`
- **Events**: `SignatureValidated(address indexed operator, bool valid)`

### AcrossIntegration Contract

#### Functions

##### `initiateRebalancing(RebalancingRequest calldata request)`
- **Description**: Initiate a cross-chain rebalancing operation
- **Parameters**:
  - `request`: Rebalancing request containing source/target chains, amount, token
- **Returns**: `string` (request ID)
- **Events**: `RebalancingInitiated(string indexed requestId, uint32 sourceChain, uint32 targetChain)`

##### `getRebalancingStatus(string calldata requestId)`
- **Description**: Get the status of a rebalancing operation
- **Parameters**:
  - `requestId`: Request ID to check
- **Returns**: `RebalancingStatus` struct
- **Events**: None

##### `getRebalancingHistory(uint32 offset, uint32 limit)`
- **Description**: Get historical rebalancing data
- **Parameters**:
  - `offset`: Offset for pagination
  - `limit`: Maximum number of records to return
- **Returns**: `RebalancingRecord[]` array
- **Events**: None

## REST APIs

### Operator API

#### Base URL
```
http://localhost:8080/api/v1
```

#### Health Check

##### `GET /health`
- **Description**: Check operator health status
- **Response**:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00Z",
  "uptime": "24h30m15s",
  "version": "0.0.1"
}
```

#### Operator Status

##### `GET /operator/status`
- **Description**: Get operator status and metrics
- **Response**:
```json
{
  "operatorId": "0x1234567890123456789012345678901234567890",
  "address": "0x1234567890123456789012345678901234567890",
  "status": "active",
  "stake": {
    "amount": "1000000000000000000000",
    "currency": "ETH"
  },
  "performance": {
    "uptime": 99.9,
    "tasksProcessed": 1500,
    "successRate": 99.8
  }
}
```

#### Task Management

##### `GET /tasks`
- **Description**: Get list of tasks
- **Query Parameters**:
  - `status`: Filter by task status (pending, processing, completed, failed)
  - `limit`: Maximum number of tasks to return (default: 50)
  - `offset`: Offset for pagination (default: 0)
- **Response**:
```json
{
  "tasks": [
    {
      "id": "task_123",
      "type": "state_update",
      "status": "completed",
      "createdAt": "2024-01-01T00:00:00Z",
      "completedAt": "2024-01-01T00:01:00Z",
      "chainId": 1,
      "poolId": "0x1234567890123456789012345678901234567890"
    }
  ],
  "total": 1500,
  "limit": 50,
  "offset": 0
}
```

##### `GET /tasks/{taskId}`
- **Description**: Get specific task details
- **Path Parameters**:
  - `taskId`: Task ID
- **Response**:
```json
{
  "id": "task_123",
  "type": "state_update",
  "status": "completed",
  "createdAt": "2024-01-01T00:00:00Z",
  "completedAt": "2024-01-01T00:01:00Z",
  "chainId": 1,
  "poolId": "0x1234567890123456789012345678901234567890",
  "data": {
    "poolState": {
      "totalLiquidity": "1000000000000000000000",
      "price": "2000000000000000000000",
      "volume24h": "50000000000000000000000"
    }
  }
}
```

#### State Management

##### `GET /state/global`
- **Description**: Get global state for all pools
- **Response**:
```json
{
  "pools": [
    {
      "poolId": "0x1234567890123456789012345678901234567890",
      "token0": "0xA0b86a33E6441c8C06Cdd0C2A4C7C4C8C8C8C8C8",
      "token1": "0x1234567890123456789012345678901234567890",
      "fee": 3000,
      "totalLiquidity": "1000000000000000000000",
      "averagePrice": "2000000000000000000000",
      "imbalanceScore": "500000000000000000000",
      "lastUpdateBlock": 19000000,
      "chainStates": {
        "1": {
          "totalLiquidity": "500000000000000000000",
          "price": "2000000000000000000000",
          "volume24h": "25000000000000000000000"
        },
        "42161": {
          "totalLiquidity": "300000000000000000000",
          "price": "2000000000000000000000",
          "volume24h": "15000000000000000000000"
        }
      }
    }
  ]
}
```

##### `GET /state/pools/{poolId}`
- **Description**: Get state for specific pool
- **Path Parameters**:
  - `poolId`: Pool ID
- **Response**:
```json
{
  "poolId": "0x1234567890123456789012345678901234567890",
  "token0": "0xA0b86a33E6441c8C06Cdd0C2A4C7C4C8C8C8C8C8",
  "token1": "0x1234567890123456789012345678901234567890",
  "fee": 3000,
  "totalLiquidity": "1000000000000000000000",
  "averagePrice": "2000000000000000000000",
  "imbalanceScore": "500000000000000000000",
  "lastUpdateBlock": 19000000,
  "chainStates": {
    "1": {
      "totalLiquidity": "500000000000000000000",
      "price": "2000000000000000000000",
      "volume24h": "25000000000000000000000"
    }
  }
}
```

#### Rebalancing

##### `GET /rebalancing/requests`
- **Description**: Get rebalancing requests
- **Query Parameters**:
  - `status`: Filter by status (pending, processing, completed, failed)
  - `limit`: Maximum number of requests to return (default: 50)
  - `offset`: Offset for pagination (default: 0)
- **Response**:
```json
{
  "requests": [
    {
      "id": "req_123",
      "sourceChainId": 1,
      "targetChainId": 42161,
      "token": "0xA0b86a33E6441c8C06Cdd0C2A4C7C4C8C8C8C8C8",
      "amount": "1000000000000000000000",
      "status": "completed",
      "createdAt": "2024-01-01T00:00:00Z",
      "completedAt": "2024-01-01T00:05:00Z",
      "transactionHash": "0x1234567890abcdef"
    }
  ],
  "total": 250,
  "limit": 50,
  "offset": 0
}
```

##### `POST /rebalancing/initiate`
- **Description**: Initiate a rebalancing request
- **Request Body**:
```json
{
  "sourceChainId": 1,
  "targetChainId": 42161,
  "token": "0xA0b86a33E6441c8C06Cdd0C2A4C7C4C8C8C8C8C8",
  "amount": "1000000000000000000000",
  "recipient": "0x1234567890123456789012345678901234567890",
  "deadline": 1704067200
}
```
- **Response**:
```json
{
  "requestId": "req_123",
  "status": "pending",
  "estimatedCost": "1000000000000000000",
  "estimatedTime": "5m"
}
```

##### `GET /rebalancing/requests/{requestId}`
- **Description**: Get rebalancing request status
- **Path Parameters**:
  - `requestId`: Request ID
- **Response**:
```json
{
  "id": "req_123",
  "sourceChainId": 1,
  "targetChainId": 42161,
  "token": "0xA0b86a33E6441c8C06Cdd0C2A4C7C4C8C8C8C8C8",
  "amount": "1000000000000000000000",
  "status": "completed",
  "createdAt": "2024-01-01T00:00:00Z",
  "completedAt": "2024-01-01T00:05:00Z",
  "transactionHash": "0x1234567890abcdef",
  "actualCost": "950000000000000000",
  "errorMessage": null
}
```

#### Metrics

##### `GET /metrics`
- **Description**: Get operator metrics
- **Response**:
```json
{
  "operator": {
    "uptime": "24h30m15s",
    "status": "active",
    "tasksProcessed": 1500,
    "successRate": 99.8
  },
  "pools": {
    "total": 10,
    "active": 8,
    "stale": 2
  },
  "rebalancing": {
    "requests": 250,
    "success": 245,
    "failures": 5
  },
  "crossChain": {
    "operations": 150,
    "success": 145,
    "failures": 5
  }
}
```

### Aggregator API

#### Base URL
```
http://localhost:8081/api/v1
```

#### Health Check

##### `GET /health`
- **Description**: Check aggregator health status
- **Response**:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00Z",
  "uptime": "24h30m15s",
  "version": "0.0.1"
}
```

#### State Aggregation

##### `GET /aggregate/global`
- **Description**: Get aggregated global state
- **Response**:
```json
{
  "timestamp": "2024-01-01T00:00:00Z",
  "pools": [
    {
      "poolId": "0x1234567890123456789012345678901234567890",
      "totalLiquidity": "1000000000000000000000",
      "averagePrice": "2000000000000000000000",
      "imbalanceScore": "500000000000000000000",
      "chainStates": {
        "1": {
          "totalLiquidity": "500000000000000000000",
          "price": "2000000000000000000000"
        }
      }
    }
  ]
}
```

## GraphQL APIs

### Schema

```graphql
type Query {
  operator: Operator
  pools(limit: Int, offset: Int): [Pool!]!
  pool(id: String!): Pool
  tasks(status: TaskStatus, limit: Int, offset: Int): [Task!]!
  task(id: String!): Task
  rebalancingRequests(status: RequestStatus, limit: Int, offset: Int): [RebalancingRequest!]!
  rebalancingRequest(id: String!): RebalancingRequest
  metrics: Metrics
}

type Mutation {
  initiateRebalancing(input: RebalancingInput!): RebalancingRequest!
}

type Subscription {
  taskUpdated: Task!
  poolStateUpdated: Pool!
  rebalancingRequestUpdated: RebalancingRequest!
}

type Operator {
  id: String!
  address: String!
  status: String!
  stake: Stake!
  performance: Performance!
}

type Pool {
  id: String!
  token0: String!
  token1: String!
  fee: Int!
  totalLiquidity: String!
  averagePrice: String!
  imbalanceScore: String!
  lastUpdateBlock: Int!
  chainStates: [ChainState!]!
}

type ChainState {
  chainId: Int!
  totalLiquidity: String!
  price: String!
  volume24h: String!
  fees24h: String!
}

type Task {
  id: String!
  type: String!
  status: TaskStatus!
  createdAt: String!
  completedAt: String
  chainId: Int!
  poolId: String!
  data: JSON
}

type RebalancingRequest {
  id: String!
  sourceChainId: Int!
  targetChainId: Int!
  token: String!
  amount: String!
  status: RequestStatus!
  createdAt: String!
  completedAt: String
  transactionHash: String
  actualCost: String
  errorMessage: String
}

type Stake {
  amount: String!
  currency: String!
}

type Performance {
  uptime: Float!
  tasksProcessed: Int!
  successRate: Float!
}

type Metrics {
  operator: OperatorMetrics!
  pools: PoolMetrics!
  rebalancing: RebalancingMetrics!
  crossChain: CrossChainMetrics!
}

type OperatorMetrics {
  uptime: String!
  status: String!
  tasksProcessed: Int!
  successRate: Float!
}

type PoolMetrics {
  total: Int!
  active: Int!
  stale: Int!
}

type RebalancingMetrics {
  requests: Int!
  success: Int!
  failures: Int!
}

type CrossChainMetrics {
  operations: Int!
  success: Int!
  failures: Int!
}

enum TaskStatus {
  PENDING
  PROCESSING
  COMPLETED
  FAILED
}

enum RequestStatus {
  PENDING
  PROCESSING
  COMPLETED
  FAILED
}

input RebalancingInput {
  sourceChainId: Int!
  targetChainId: Int!
  token: String!
  amount: String!
  recipient: String!
  deadline: Int!
}

scalar JSON
```

### Example Queries

#### Get Operator Status
```graphql
query GetOperatorStatus {
  operator {
    id
    address
    status
    stake {
      amount
      currency
    }
    performance {
      uptime
      tasksProcessed
      successRate
    }
  }
}
```

#### Get Pools with Pagination
```graphql
query GetPools($limit: Int, $offset: Int) {
  pools(limit: $limit, offset: $offset) {
    id
    token0
    token1
    fee
    totalLiquidity
    averagePrice
    imbalanceScore
    chainStates {
      chainId
      totalLiquidity
      price
    }
  }
}
```

#### Subscribe to Task Updates
```graphql
subscription TaskUpdates {
  taskUpdated {
    id
    type
    status
    createdAt
    completedAt
    chainId
    poolId
  }
}
```

## WebSocket APIs

### Connection
```javascript
const ws = new WebSocket('ws://localhost:8080/ws');
```

### Message Format
```json
{
  "type": "subscribe|unsubscribe|message",
  "channel": "tasks|pools|rebalancing",
  "data": {}
}
```

### Channels

#### Tasks Channel
- **Subscribe**: `{"type": "subscribe", "channel": "tasks"}`
- **Messages**: Task updates and status changes

#### Pools Channel
- **Subscribe**: `{"type": "subscribe", "channel": "pools"}`
- **Messages**: Pool state updates and changes

#### Rebalancing Channel
- **Subscribe**: `{"type": "subscribe", "channel": "rebalancing"}`
- **Messages**: Rebalancing request updates and status changes

## Error Codes

### HTTP Status Codes
- `200`: Success
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found
- `429`: Too Many Requests
- `500`: Internal Server Error
- `503`: Service Unavailable

### Error Response Format
```json
{
  "error": {
    "code": "INVALID_REQUEST",
    "message": "Invalid request parameters",
    "details": {
      "field": "amount",
      "reason": "Must be a positive number"
    }
  }
}
```

### Error Codes
- `INVALID_REQUEST`: Invalid request parameters
- `UNAUTHORIZED`: Authentication required
- `FORBIDDEN`: Insufficient permissions
- `NOT_FOUND`: Resource not found
- `RATE_LIMITED`: Rate limit exceeded
- `INTERNAL_ERROR`: Internal server error
- `SERVICE_UNAVAILABLE`: Service temporarily unavailable
- `VALIDATION_ERROR`: Data validation failed
- `NETWORK_ERROR`: Network connectivity issue
- `CONTRACT_ERROR`: Smart contract interaction failed

## Rate Limits

### Default Limits
- **API Calls**: 1000 requests per minute per IP
- **WebSocket Connections**: 10 connections per IP
- **GraphQL Queries**: 100 queries per minute per IP

### Rate Limit Headers
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
```

### Rate Limit Exceeded Response
```json
{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Rate limit exceeded",
    "retryAfter": 60
  }
}
```

## Authentication

### API Key Authentication
```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:8080/api/v1/operator/status
```

### JWT Token Authentication
```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:8080/api/v1/operator/status
```

## SDKs and Libraries

### JavaScript/TypeScript
```bash
npm install @synchook/sdk
```

```javascript
import { SyncHookClient } from '@synchook/sdk';

const client = new SyncHookClient({
  operatorUrl: 'http://localhost:8080',
  aggregatorUrl: 'http://localhost:8081'
});

// Get operator status
const status = await client.operator.getStatus();

// Initiate rebalancing
const request = await client.rebalancing.initiate({
  sourceChainId: 1,
  targetChainId: 42161,
  token: '0x...',
  amount: '1000000000000000000000'
});
```

### Python
```bash
pip install synchook-sdk
```

```python
from synchook import SyncHookClient

client = SyncHookClient(
    operator_url='http://localhost:8080',
    aggregator_url='http://localhost:8081'
)

# Get operator status
status = client.operator.get_status()

# Initiate rebalancing
request = client.rebalancing.initiate(
    source_chain_id=1,
    target_chain_id=42161,
    token='0x...',
    amount='1000000000000000000000'
)
```

### Go
```bash
go get github.com/synchook/sdk-go
```

```go
package main

import (
    "github.com/synchook/sdk-go"
)

func main() {
    client := synchook.NewClient(
        "http://localhost:8080",
        "http://localhost:8081",
    )
    
    // Get operator status
    status, err := client.Operator.GetStatus()
    if err != nil {
        panic(err)
    }
    
    // Initiate rebalancing
    request, err := client.Rebalancing.Initiate(synchook.RebalancingRequest{
        SourceChainID: 1,
        TargetChainID: 42161,
        Token: "0x...",
        Amount: "1000000000000000000000",
    })
    if err != nil {
        panic(err)
    }
}
```

## Testing

### Postman Collection
```bash
# Import the Postman collection
curl -o synchook-api.postman_collection.json \
  https://raw.githubusercontent.com/synchook/api-docs/main/postman/synchook-api.postman_collection.json
```

### cURL Examples
```bash
# Health check
curl http://localhost:8080/api/v1/health

# Get operator status
curl http://localhost:8080/api/v1/operator/status

# Get pools
curl http://localhost:8080/api/v1/state/global

# Initiate rebalancing
curl -X POST http://localhost:8080/api/v1/rebalancing/initiate \
  -H "Content-Type: application/json" \
  -d '{
    "sourceChainId": 1,
    "targetChainId": 42161,
    "token": "0xA0b86a33E6441c8C06Cdd0C2A4C7C4C8C8C8C8C8",
    "amount": "1000000000000000000000",
    "recipient": "0x1234567890123456789012345678901234567890",
    "deadline": 1704067200
  }'
```

## Changelog

### Version 0.0.1
- Initial API release
- Basic operator and aggregator endpoints
- GraphQL support
- WebSocket subscriptions
- Authentication support

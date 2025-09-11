// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {TestSyncHookForIntegration} from "../helpers/TestSyncHookForIntegration.sol";
import {SyncAVS} from "../../src/avs/SyncAVS.sol";
import {ISyncAVS} from "../../src/hooks/interfaces/ISyncAVS.sol";
import {SyncTaskManager} from "../../src/avs/SyncTaskManager.sol";
import {StateValidationMiddleware} from "../../src/avs/StateValidationMiddleware.sol";
import {AcrossIntegration} from "../../src/integration/AcrossIntegration.sol";
import {IAcrossIntegration} from "../../src/hooks/interfaces/IAcrossIntegration.sol";
import {StateOracles} from "../../src/integration/StateOracles.sol";
import {ChainRegistry} from "../../src/integration/ChainRegistry.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer/contracts/interfaces/IPermissionController.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta, toBalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

contract CompleteFlowTest is Test {
    // Core contracts
    TestSyncHookForIntegration public syncHook;
    SyncAVS public syncAVS;
    SyncTaskManager public syncTaskManager;
    StateValidationMiddleware public stateValidation;
    AcrossIntegration public acrossIntegration;
    StateOracles public stateOracles;
    ChainRegistry public chainRegistry;
    
    // Test addresses
    address public owner = address(0x1);
    address public operator = address(0x2);
    address public user = address(0x3);
    address public token = address(0x1000);
    address public counterToken = address(0x2000);
    
    // Pool setup
    Currency public currency0;
    Currency public currency1;
    PoolKey public poolKey;
    
    function setUp() public {
        // Deploy StateOracles
        stateOracles = new StateOracles();
        
        // Deploy ChainRegistry
        chainRegistry = new ChainRegistry();
        
        // Deploy StateValidationMiddleware
        stateValidation = new StateValidationMiddleware(
            address(0), // syncAVS - will be updated
            address(0), // slashingRegistry
            0.01e18, // validationReward
            0.1e18, // slashingPenalty
            75 // consensusThreshold
        );
        
        // Deploy SyncAVS
        syncAVS = new SyncAVS(
            IAVSDirectory(address(0x1000)),
            IRewardsCoordinator(address(0x2000)),
            ISlashingRegistryCoordinator(address(0x3000)),
            IStakeRegistry(address(0x4000)),
            IPermissionController(address(0x5000)),
            IAllocationManager(address(0x6000)),
            IAcrossIntegration(address(0x7000))
        );
        
        // Deploy SyncTaskManager
        syncTaskManager = new SyncTaskManager(
            address(syncAVS),
            address(stateValidation),
            0.001e18, // taskCreationFee
            0.005e18, // taskCompletionReward
            0.01e18   // taskFailurePenalty
        );
        
        // Deploy AcrossIntegration
        acrossIntegration = new AcrossIntegration(
            address(0x8000), // spokePool
            address(syncAVS),
            10, // bridgeFeeBps
            1000000e18, // maxRebalancingAmount
            1000e18, // minRebalancingAmount
            100 // rebalancingCooldown
        );
        
        // Deploy SyncHook directly
        syncHook = new TestSyncHookForIntegration(
            IPoolManager(address(0xA000)), // poolManager
            ISyncAVS(address(syncAVS)),
            IAcrossIntegration(address(acrossIntegration)),
            owner
        );
        
        // Setup currencies and pool key
        currency0 = Currency.wrap(token);
        currency1 = Currency.wrap(counterToken);
        
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(syncHook))
        });
        
        // Setup initial configuration
        _setupInitialConfig();
    }
    
    function _setupInitialConfig() internal {
        // Configure chains
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
        chainRegistry.addChain(137, "Polygon", address(0x2000), 10000000000, 2);
        
        // Configure oracles
        address oracle = address(0x3000);
        stateOracles.authorizeOracle(oracle);
        stateOracles.addOracle(token, oracle, 1e18, 8);
        stateOracles.addOracle(counterToken, oracle, 1e18, 8);
        
        // Configure Across integration
        acrossIntegration.addSupportedChain(1);
        acrossIntegration.addSupportedChain(137);
    }
    
    function test_CompleteSwapFlow() public {
        // 1. User performs a swap
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000e18,
            sqrtPriceLimitX96: 0
        });
        
        // Before swap hook
        syncHook.beforeSwap(address(this), poolKey, params, "");
        
        // Simulate swap execution
        BalanceDelta delta = toBalanceDelta(int128(1000e18), int128(-2000e18));
        
        // After swap hook
        syncHook.afterSwap(address(this), poolKey, params, delta, "");
        
        // 2. Operator submits state update
        syncAVS.registerOperator(operator, "test-operator");
        
        SyncAVS.PoolState memory poolState = SyncAVS.PoolState({
            totalLiquidity: 1000000e18,
            price: 2000e18,
            volume24h: 100000e18,
            fees24h: 1000e18,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
        
        syncAVS.submitStateUpdate(1, poolState, "");
        
        // 3. Check if rebalancing should be triggered
        (bool shouldRebalance, uint256 sourceChain, uint256 targetChain, uint256 amount) = 
            syncAVS.shouldTriggerRebalancing(currency0, currency1);
        assertFalse(shouldRebalance); // Should be false initially
        
        // 4. Manually trigger rebalancing
        uint256 taskId = syncAVS.initiateRebalancing(1, 137, 1000e18, token);
        assertTrue(taskId > 0);
        
        // 5. Task manager processes the task
        syncTaskManager.assignTask(taskId, operator);
        
        vm.prank(operator);
        syncTaskManager.startTask(taskId);
        
        vm.prank(operator);
        syncTaskManager.completeTask(taskId, "rebalancing_completed");
        
        // 6. Check task completion
        SyncTaskManager.Task memory task = syncTaskManager.getTask(taskId);
        assertEq(uint256(task.status), 3); // Completed
    }
    
    function test_CompleteLiquidityFlow() public {
        // 1. User adds liquidity
        BalanceDelta delta = toBalanceDelta(int128(1000e18), int128(2000e18));
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: 1000e18,
            salt: bytes32(0)
        });
        BalanceDelta feesAccrued = toBalanceDelta(0, 0);
        
        syncHook.beforeAddLiquidity(address(this), poolKey, params, "");
        syncHook.afterAddLiquidity(address(this), poolKey, params, delta, feesAccrued, "");
        
        // 2. Operator submits updated state
        syncAVS.registerOperator(operator, "test-operator");
        
        SyncAVS.PoolState memory poolState = SyncAVS.PoolState({
            totalLiquidity: 2000000e18, // Increased liquidity
            price: 2000e18,
            volume24h: 50000e18,
            fees24h: 500e18,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
        
        syncAVS.submitStateUpdate(1, poolState, "");
        
        // 3. Check global state
        (uint256 totalLiquidity, uint256 averagePrice, uint256 imbalanceScore, uint256 lastUpdateBlock) = 
            syncAVS.getGlobalState(currency0, currency1);
        assertTrue(totalLiquidity > 0);
    }
    
    function test_CompleteRemovalFlow() public {
        // 1. User removes liquidity
        BalanceDelta delta = toBalanceDelta(int128(-500e18), int128(-1000e18));
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -100,
            tickUpper: 100,
            liquidityDelta: -1000e18,
            salt: bytes32(0)
        });
        BalanceDelta feesAccrued = toBalanceDelta(0, 0);
        
        syncHook.beforeRemoveLiquidity(address(this), poolKey, params, "");
        syncHook.afterRemoveLiquidity(address(this), poolKey, params, delta, feesAccrued, "");
        
        // 2. Operator submits updated state
        syncAVS.registerOperator(operator, "test-operator");
        
        SyncAVS.PoolState memory poolState = SyncAVS.PoolState({
            totalLiquidity: 500000e18, // Decreased liquidity
            price: 2000e18,
            volume24h: 25000e18,
            fees24h: 250e18,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
        
        syncAVS.submitStateUpdate(1, poolState, "");
        
        // 3. Check if rebalancing is needed
        (bool shouldRebalance, uint256 sourceChain, uint256 targetChain, uint256 amount) = 
            syncAVS.shouldTriggerRebalancing(currency0, currency1);
        // Should be false for small changes
        assertFalse(shouldRebalance);
    }
    
    function test_CrossChainRebalancing() public {
        // 1. Setup operator
        syncAVS.registerOperator(operator, "test-operator");
        
        // 2. Trigger rebalancing between chains
        uint256 taskId = syncAVS.initiateRebalancing(1, 137, 10000e18, token);
        assertTrue(taskId > 0);
        
        // 3. Process rebalancing through Across integration
        bytes32 requestId = acrossIntegration.requestRebalancing(
            token,
            counterToken,
            10000e18
        );
        
        assertTrue(requestId != bytes32(0));
        
        // 4. Check rebalancing request
        AcrossIntegration.RebalancingRequest memory request = acrossIntegration.getRebalancingRequest(requestId);
        assertEq(request.sourceChain, 1);
        assertEq(request.targetChain, 137);
        assertEq(request.token, token);
        assertEq(request.amount, 10000e18);
        assertTrue(request.executed);
    }
    
    function test_StateValidationFlow() public {
        // 1. Setup operator
        syncAVS.registerOperator(operator, "test-operator");
        
        // 2. Submit task response
        stateValidation.submitTaskResponse(1, "test_response", "");
        
        // 3. Validate operator signature
        bool isValid = stateValidation.validateOperatorSignature(
            operator,
            bytes32(0),
            ""
        );
        assertFalse(isValid); // Should be false for unregistered operator in validation
        
        // 4. Get validation stats
        (
            uint256 totalValidations,
            uint256 successfulValidations,
            uint256 failedValidations,
            uint256 averageConfidence
        ) = stateValidation.getValidationStats(operator);
        
        assertEq(totalValidations, 0);
        assertEq(successfulValidations, 0);
        assertEq(failedValidations, 0);
        assertEq(averageConfidence, 80e16);
    }
    
    function test_OracleIntegration() public {
        // 1. Update price data
        stateOracles.updatePrice(token);
        
        // 2. Update liquidity data
        stateOracles.updateLiquidity(
            token,
            1000000e18, // totalLiquidity
            500000e18,  // token0Reserves
            500000e18   // token1Reserves
        );
        
        // 3. Get price data
        (uint256 price, uint256 confidence, uint256 timestamp) = stateOracles.getPrice(token);
        assertTrue(price > 0);
        assertTrue(confidence > 0);
        assertTrue(timestamp > 0);
        
        // 4. Get liquidity data
        (
            uint256 totalLiquidity,
            uint256 token0Reserves,
            uint256 token1Reserves,
            uint256 liquidityTimestamp
        ) = stateOracles.getLiquidity(token);
        
        assertEq(totalLiquidity, 1000000e18);
        assertEq(token0Reserves, 500000e18);
        assertEq(token1Reserves, 500000e18);
        assertTrue(liquidityTimestamp > 0);
    }
    
    function test_ChainRegistryIntegration() public {
        // 1. Add more chains
        chainRegistry.addChain(42161, "Arbitrum", address(0x3000), 5000000000, 1);
        
        // 2. Check chain support
        assertTrue(chainRegistry.isChainSupported(1));
        assertTrue(chainRegistry.isChainSupported(137));
        assertTrue(chainRegistry.isChainSupported(42161));
        
        // 3. Get optimal chain for different operations
        uint256 optimalChain = chainRegistry.getOptimalChain(1); // Low cost
        assertTrue(optimalChain == 1 || optimalChain == 137 || optimalChain == 42161);
        
        // 4. Get chain statistics
        (
            uint256 totalChains,
            uint256 activeChains,
            uint256 averageGasPrice,
            uint256 averageBlockTime
        ) = chainRegistry.getChainStatistics();
        
        assertEq(totalChains, 3);
        assertEq(activeChains, 3);
        assertTrue(averageGasPrice > 0);
        assertTrue(averageBlockTime > 0);
    }
    
    function test_ErrorHandling() public {
        // Test invalid operations
        vm.expectRevert();
        syncAVS.submitStateUpdate(1, SyncAVS.PoolState(0, 0, 0, 0, 0, 0), "");
        
        vm.expectRevert();
        syncTaskManager.getTask(999);
        
        vm.expectRevert();
        acrossIntegration.getRebalancingRequest(bytes32(0));
    }
    
    function test_AccessControl() public {
        // Test only owner functions
        vm.prank(user);
        vm.expectRevert();
        // syncHook.updateSyncAVS(syncAVS); // Function not implemented
        
        vm.prank(user);
        vm.expectRevert();
        syncAVS.updateSlashingParameters(10e16, 1e18);
        
        vm.prank(user);
        vm.expectRevert();
        syncTaskManager.updateTaskConfig(0.002e18, 0.01e18, 0.02e18);
    }
}

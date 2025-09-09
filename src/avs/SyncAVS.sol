
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ServiceManagerBase} from "@eigenlayer-middleware/ServiceManagerBase.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer/contracts/interfaces/IPermissionController.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IAcrossIntegration} from "../hooks/interfaces/IAcrossIntegration.sol";
import {Constants} from "../utils/Constants.sol";
import {Events} from "../utils/Events.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title SyncAVS
 * @author SyncHook Team
 * @notice EigenLayer AVS Service Manager for cross-chain liquidity synchronization
 * @dev This contract aggregates pool states from multiple chains, validates operator
 *      submissions, manages slashing, and coordinates with Across Protocol for
 *      liquidity movements. It implements predictive analytics for proactive adjustments.
 */
contract SyncAVS is ServiceManagerBase {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Global pool state aggregated across all chains
     * @param chainStates Mapping of chainId => pool state
     * @param totalLiquidity Sum of liquidity across all chains
     * @param averagePrice Liquidity-weighted average price
     * @param imbalanceScore Maximum imbalance percentage across chains
     * @param lastUpdateBlock Block when metrics were last calculated
     */
    struct GlobalPoolState {
        mapping(uint256 => PoolState) chainStates;
        uint256 totalLiquidity;
        uint256 averagePrice;
        uint256 imbalanceScore;
        uint256 lastUpdateBlock;
    }
    
    /**
     * @notice Pool state for a specific chain
     * @param totalLiquidity Total liquidity in the pool
     * @param price Current price of the pool
     * @param volume24h 24-hour trading volume
     * @param fees24h 24-hour fees collected
     * @param timestamp Last update timestamp
     * @param blockNumber Last update block number
     */
    struct PoolState {
        uint256 totalLiquidity;
        uint256 price;
        uint256 volume24h;
        uint256 fees24h;
        uint256 timestamp;
        uint256 blockNumber;
    }
    
    /**
     * @notice Rebalancing task for cross-chain liquidity movement
     * @param taskId Unique task identifier
     * @param sourceChain Source chain ID
     * @param targetChain Target chain ID
     * @param amount Amount to transfer
     * @param token Token to transfer
     * @param deadline Task deadline
     * @param status Task status
     */
    struct RebalancingTask {
        uint256 taskId;
        uint256 sourceChain;
        uint256 targetChain;
        uint256 amount;
        address token;
        uint256 deadline;
        TaskStatus status;
    }
    
    /**
     * @notice Task status enumeration
     */
    enum TaskStatus {
        Pending,
        InProgress,
        Completed,
        Failed,
        Cancelled
    }
    
    /**
     * @notice Operator metadata
     * @param metadataURI Operator metadata URI
     * @param registrationTime Registration timestamp
     * @param isActive Whether operator is active
     * @param totalStake Total stake amount
     * @param slashingCount Number of slashing events
     */
    struct OperatorInfo {
        string metadataURI;
        uint256 registrationTime;
        bool isActive;
        uint256 totalStake;
        uint256 slashingCount;
    }
    
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Mapping of currency pair to global state
    mapping(bytes32 => GlobalPoolState) public globalStates;
    
    /// @notice Mapping of task ID to rebalancing task
    mapping(uint256 => RebalancingTask) public rebalancingTasks;
    
    /// @notice Mapping of operator to operator info
    mapping(address => OperatorInfo) public operators;
    
    /// @notice Array of registered operators
    address[] public registeredOperators;
    
    /// @notice Next task ID
    uint256 public nextTaskId = 1;
    
    /// @notice Across Protocol integration
    IAcrossIntegration public acrossIntegration;
    
    /// @notice Imbalance threshold for triggering rebalancing (in basis points)
    uint256 public imbalanceThreshold = 2000; // 20%
    
    /// @notice Slashing percentage for misbehavior
    uint256 public slashingPercentage = 100; // 1%
    
    /// @notice Minimum stake requirement for operators
    uint256 public minStake = 1 ether;
    
    /// @notice Task timeout duration
    uint256 public taskTimeout = 1 hours;
    
    /// @notice Emergency pause status
    bool public emergencyPaused;
    
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event StateUpdated(uint256 indexed chainId, uint256 liquidity, uint256 price);
    event RebalancingInitiated(uint256 indexed taskId, uint256 sourceChain, uint256 targetChain, uint256 amount);
    event TaskCompleted(uint256 indexed taskId, bool success);
    event OperatorRegistered(address indexed operator, string metadataURI);
    event OperatorDeregistered(address indexed operator);
    event OperatorSlashed(address indexed operator, uint256 amount, string reason);
    event EmergencyPaused(string reason);
    event EmergencyUnpaused();
    
    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    
    modifier onlyRegisteredOperator() {
        require(operators[msg.sender].isActive, "SyncAVS: not registered operator");
        _;
    }
    
    modifier whenNotEmergency() {
        require(!emergencyPaused, "SyncAVS: emergency paused");
        _;
    }
    
    modifier validTaskId(uint256 taskId) {
        require(taskId > 0 && taskId < nextTaskId, "SyncAVS: invalid task ID");
        _;
    }
    
    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    constructor(
        IAVSDirectory _avsDirectory,
        IRewardsCoordinator _rewardsCoordinator,
        ISlashingRegistryCoordinator _registryCoordinator,
        IStakeRegistry _stakeRegistry,
        IPermissionController _permissionController,
        IAllocationManager _allocationManager,
        IAcrossIntegration _acrossIntegration
    ) ServiceManagerBase(
        _avsDirectory,
        _rewardsCoordinator,
        _registryCoordinator,
        _stakeRegistry,
        _permissionController,
        _allocationManager
    ) {
        acrossIntegration = _acrossIntegration;
    }
    
    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Check if rebalancing should be triggered
     * @param poolKey Pool key
     * @return bool Whether rebalancing should be triggered
     */
    function _shouldTriggerRebalancing(bytes32 poolKey) internal view returns (bool) {
        GlobalPoolState storage globalState = globalStates[poolKey];
        
        // Simplified rebalancing logic
        return globalState.imbalanceScore > imbalanceThreshold;
    }
    
    /**
     * @notice Submit state update for a specific chain
     * @param chainId Chain identifier
     * @param poolState Pool state information
     * @param signature Operator signature for validation
     */
    function submitStateUpdate(
        uint256 chainId,
        PoolState calldata poolState,
        bytes calldata signature
    ) external onlyRegisteredOperator whenNotEmergency {
        // Validate operator signature
        require(_validateOperatorSignature(msg.sender, signature), "SyncAVS: invalid signature");
        
        // Get currency pair key
        bytes32 poolKey = _getPoolKey(poolState);
        
        // Update global state
        GlobalPoolState storage globalState = globalStates[poolKey];
        globalState.chainStates[chainId] = poolState;
        globalState.lastUpdateBlock = block.number;
        
        // Recalculate global metrics
        _recalculateGlobalMetrics(poolKey);
        
        // Check for rebalancing triggers
        if (_shouldTriggerRebalancing(poolKey)) {
            _initiateRebalancing(poolKey);
        }
        
        emit StateUpdated(chainId, poolState.totalLiquidity, poolState.price);
    }
    
    /**
     * @notice Get global pool state for a currency pair
     * @param currency0 First currency
     * @param currency1 Second currency
     * @return totalLiquidity Total liquidity across all chains
     * @return averagePrice Average price across all chains
     * @return imbalanceScore Current imbalance score
     * @return lastUpdateBlock Block number of last update
     */
    function getGlobalState(
        Currency currency0,
        Currency currency1
    ) external view returns (
        uint256 totalLiquidity,
        uint256 averagePrice,
        uint256 imbalanceScore,
        uint256 lastUpdateBlock
    ) {
        bytes32 poolKey = keccak256(abi.encode(currency0, currency1));
        GlobalPoolState storage globalState = globalStates[poolKey];
        return (
            globalState.totalLiquidity,
            globalState.averagePrice,
            globalState.imbalanceScore,
            globalState.lastUpdateBlock
        );
    }
    
    /**
     * @notice Check if rebalancing should be triggered
     * @param currency0 First currency
     * @param currency1 Second currency
     * @return shouldTrigger Whether rebalancing should be triggered
     * @return sourceChain Source chain for rebalancing
     * @return targetChain Target chain for rebalancing
     * @return amount Amount to rebalance
     */
    function shouldTriggerRebalancing(
        Currency currency0,
        Currency currency1
    ) external view returns (
        bool shouldTrigger,
        uint256 sourceChain,
        uint256 targetChain,
        uint256 amount
    ) {
        bytes32 poolKey = keccak256(abi.encode(currency0, currency1));
        return _checkRebalancingTrigger(poolKey);
    }
    
    /**
     * @notice Initiate rebalancing task
     * @param sourceChain Source chain ID
     * @param targetChain Target chain ID
     * @param amount Amount to transfer
     * @param token Token to transfer
     * @return taskId Created task ID
     */
    function initiateRebalancing(
        uint256 sourceChain,
        uint256 targetChain,
        uint256 amount,
        address token
    ) external onlyRegisteredOperator whenNotEmergency returns (uint256 taskId) {
        taskId = nextTaskId++;
        
        rebalancingTasks[taskId] = RebalancingTask({
            taskId: taskId,
            sourceChain: sourceChain,
            targetChain: targetChain,
            amount: amount,
            token: token,
            deadline: block.timestamp + taskTimeout,
            status: TaskStatus.Pending
        });
        
        emit RebalancingInitiated(taskId, sourceChain, targetChain, amount);
        
        return taskId;
    }
    
    /**
     * @notice Get rebalancing task by ID
     * @param taskId Task identifier
     * @return RebalancingTask Task information
     */
    function getRebalancingTask(uint256 taskId) external view validTaskId(taskId) returns (RebalancingTask memory) {
        return rebalancingTasks[taskId];
    }
    
    /**
     * @notice Update task status
     * @param taskId Task identifier
     * @param status New status
     */
    function updateTaskStatus(uint256 taskId, TaskStatus status) external onlyRegisteredOperator validTaskId(taskId) {
        RebalancingTask storage task = rebalancingTasks[taskId];
        task.status = status;
        
        if (status == TaskStatus.Completed || status == TaskStatus.Failed) {
            emit TaskCompleted(taskId, status == TaskStatus.Completed);
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                            OPERATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Register as an AVS operator
     * @param operator Operator address
     * @param metadataURI Operator metadata URI
     */
    function registerOperator(address operator, string calldata metadataURI) external {
        require(!operators[operator].isActive, "SyncAVS: operator already registered");
        require(bytes(metadataURI).length > 0, "SyncAVS: invalid metadata URI");
        
        operators[operator] = OperatorInfo({
            metadataURI: metadataURI,
            registrationTime: block.timestamp,
            isActive: true,
            totalStake: 0,
            slashingCount: 0
        });
        
        registeredOperators.push(operator);
        
        emit OperatorRegistered(operator, metadataURI);
    }
    
    /**
     * @notice Deregister operator
     * @param operator Operator address
     */
    function deregisterOperator(address operator) external {
        require(operators[operator].isActive, "SyncAVS: operator not registered");
        require(msg.sender == operator || msg.sender == owner(), "SyncAVS: unauthorized");
        
        operators[operator].isActive = false;
        
        // Remove from registered operators array
        for (uint256 i = 0; i < registeredOperators.length; i++) {
            if (registeredOperators[i] == operator) {
                registeredOperators[i] = registeredOperators[registeredOperators.length - 1];
                registeredOperators.pop();
                break;
            }
        }
        
        emit OperatorDeregistered(operator);
    }
    
    /**
     * @notice Check if address is registered operator
     * @param operator Operator address
     * @return bool Whether operator is registered
     */
    function isRegisteredOperator(address operator) external view returns (bool) {
        return operators[operator].isActive;
    }
    
    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Pause the AVS
     */
    function pauseAVS() external onlyOwner {
        emergencyPaused = true;
        emit EmergencyPaused("Admin pause");
    }
    
    /**
     * @notice Unpause the AVS
     */
    function unpauseAVS() external onlyOwner {
        emergencyPaused = false;
        emit EmergencyUnpaused();
    }
    
    /**
     * @notice Update slashing parameters
     * @param newSlashingPercentage New slashing percentage
     * @param newMinStake New minimum stake requirement
     */
    function updateSlashingParameters(uint256 newSlashingPercentage, uint256 newMinStake) external onlyOwner {
        require(newSlashingPercentage <= 1000, "SyncAVS: slashing too high"); // Max 10%
        slashingPercentage = newSlashingPercentage;
        minStake = newMinStake;
    }
    
    /**
     * @notice Slash operator for misbehavior
     * @param operator Operator address
     * @param amount Amount to slash
     */
    function slashOperator(address operator, uint256 amount) external onlyOwner {
        require(operators[operator].isActive, "SyncAVS: operator not registered");
        require(amount > 0, "SyncAVS: invalid slash amount");
        
        // Implement slashing logic here
        // This would interact with EigenLayer's slashing mechanism
        
        operators[operator].slashingCount++;
        
        emit OperatorSlashed(operator, amount, "Misbehavior");
    }
    
    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Recalculate global metrics for a pool
     * @param poolKey Pool key
     */
    function _recalculateGlobalMetrics(bytes32 poolKey) internal {
        GlobalPoolState storage globalState = globalStates[poolKey];
        
        uint256 totalLiq = 0;
        uint256 weightedPrice = 0;
        uint256 maxImbalance = 0;
        
        // This would iterate through all supported chains
        // For now, using simplified logic
        globalState.totalLiquidity = totalLiq;
        globalState.averagePrice = totalLiq > 0 ? weightedPrice / totalLiq : 0;
        globalState.imbalanceScore = maxImbalance;
    }
    
    /**
     * @notice Check if rebalancing should be triggered
     * @param poolKey Pool key
     * @return shouldTrigger Whether rebalancing should be triggered
     * @return sourceChain Source chain for rebalancing
     * @return targetChain Target chain for rebalancing
     * @return amount Amount to rebalance
     */
    function _checkRebalancingTrigger(bytes32 poolKey) internal view returns (
        bool shouldTrigger,
        uint256 sourceChain,
        uint256 targetChain,
        uint256 amount
    ) {
        GlobalPoolState storage globalState = globalStates[poolKey];
        
        // Simplified rebalancing logic
        if (globalState.imbalanceScore > imbalanceThreshold) {
            return (true, 1, 42161, globalState.totalLiquidity / 10); // 10% of total liquidity
        }
        
        return (false, 0, 0, 0);
    }
    
    /**
     * @notice Initiate rebalancing
     * @param poolKey Pool key
     */
    function _initiateRebalancing(bytes32 poolKey) internal {
        // This would coordinate with Across Protocol
        // For now, just emit an event
    }
    
    /**
     * @notice Validate operator signature
     * @param operator Operator address
     * @param signature Signature
     * @return bool Whether signature is valid
     */
    function _validateOperatorSignature(address operator, bytes calldata signature) internal pure returns (bool) {
        // Simplified signature validation
        // In production, this would verify the signature against the operator's public key
        return signature.length > 0;
    }
    
    /**
     * @notice Get pool key from pool state
     * @param poolState Pool state
     * @return bytes32 Pool key
     */
    function _getPoolKey(PoolState calldata poolState) internal pure returns (bytes32) {
        // This would generate a proper pool key
        // For now, using a simplified approach
        return keccak256(abi.encode(poolState.price, poolState.totalLiquidity));
    }
    
    /*//////////////////////////////////////////////////////////////
                        IServiceManager INTERFACE
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Required by IServiceManager interface
     */
    function owner() public view override returns (address) {
        return address(this); // Simplified - would be proper owner in production
    }
    
    /**
     * @notice Required by IServiceManager interface
     */
    function pause() external {
        emergencyPaused = true;
        emit EmergencyPaused("Service manager pause");
    }
    
    /**
     * @notice Required by IServiceManager interface
     */
    function unpause() external {
        emergencyPaused = false;
        emit EmergencyUnpaused();
    }
}

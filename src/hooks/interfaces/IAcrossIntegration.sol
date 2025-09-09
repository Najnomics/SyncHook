// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IAcrossIntegration
 * @notice Interface for Across Protocol integration
 * @dev This interface defines the contract for cross-chain liquidity movement
 *      using Across Protocol's intent-based architecture
 */
interface IAcrossIntegration {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Rebalancing request for cross-chain transfer
     * @param sourceChain Source chain ID
     * @param targetChain Target chain ID
     * @param token Token to transfer
     * @param amount Amount to transfer
     * @param timestamp Request timestamp
     * @param executed Whether the request has been executed
     */
    struct RebalancingRequest {
        uint256 sourceChain;
        uint256 targetChain;
        address token;
        uint256 amount;
        uint256 timestamp;
        bool executed;
    }
    
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event RebalancingRequested(
        bytes32 indexed requestId,
        uint256 indexed targetChain,
        uint256 amount
    );
    
    event RebalancingExecuted(
        bytes32 indexed requestId,
        uint64 indexed depositId
    );
    
    event RebalancingFailed(
        bytes32 indexed requestId,
        string reason
    );
    
    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Request rebalancing via Across Protocol
     * @param token Token to transfer
     * @param counterToken Counter token for the pair
     * @param imbalanceAmount Amount of imbalance to correct
     * @return requestId Created request ID
     */
    function requestRebalancing(
        address token,
        address counterToken,
        uint256 imbalanceAmount
    ) external returns (bytes32 requestId);
    
    /**
     * @notice Execute rebalancing request
     * @param requestId Request identifier
     */
    function executeRebalancing(bytes32 requestId) external;
    
    /**
     * @notice Get rebalancing request by ID
     * @param requestId Request identifier
     * @return RebalancingRequest Request information
     */
    function getRebalancingRequest(bytes32 requestId) external view returns (RebalancingRequest memory);
    
    /**
     * @notice Check if rebalancing is in progress for a token pair
     * @param token Token address
     * @param counterToken Counter token address
     * @return bool Whether rebalancing is in progress
     */
    function isRebalancingInProgress(
        address token,
        address counterToken
    ) external view returns (bool);
    
    /**
     * @notice Calculate optimal rebalancing scenario
     * @param token Token address
     * @param counterToken Counter token address
     * @param imbalanceAmount Imbalance amount
     * @return targetChain Optimal target chain
     * @return transferAmount Optimal transfer amount
     */
    function calculateOptimalRebalancing(
        address token,
        address counterToken,
        uint256 imbalanceAmount
    ) external view returns (uint256 targetChain, uint256 transferAmount);
    
    /**
     * @notice Get Across Protocol spoke pool address
     * @return address Spoke pool address
     */
    function spokePool() external view returns (address);
    
    /**
     * @notice Get supported destination chains
     * @return uint256[] Array of supported chain IDs
     */
    function getSupportedChains() external view returns (uint256[] memory);
    
    /**
     * @notice Check if chain is supported for rebalancing
     * @param chainId Chain identifier
     * @return bool Whether chain is supported
     */
    function isChainSupported(uint256 chainId) external view returns (bool);
    
    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Add supported chain
     * @param chainId Chain identifier
     */
    function addSupportedChain(uint256 chainId) external;
    
    /**
     * @notice Remove supported chain
     * @param chainId Chain identifier
     */
    function removeSupportedChain(uint256 chainId) external;
    
    /**
     * @notice Update Across Protocol configuration
     * @param newSpokePool New spoke pool address
     * @param newRelayer New relayer address
     */
    function updateAcrossConfig(address newSpokePool, address newRelayer) external;
    
    /**
     * @notice Emergency pause rebalancing
     */
    function pauseRebalancing() external;
    
    /**
     * @notice Resume rebalancing
     */
    function resumeRebalancing() external;
}

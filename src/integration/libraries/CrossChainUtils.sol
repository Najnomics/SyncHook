// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CrossChainUtils
 * @notice Library for cross-chain utility functions and calculations
 * @dev Provides utilities for cross-chain operations, validation, and calculations
 */
library CrossChainUtils {
    /// @notice Precision for calculations (18 decimals)
    uint256 public constant PRECISION = 1e18;
    
    /// @notice Maximum number of supported chains
    uint256 public constant MAX_CHAINS = 20;
    
    /// @notice Maximum message age (1 hour in blocks)
    uint256 public constant MAX_MESSAGE_AGE = 300; // 300 blocks at 12s per block
    
    /// @notice Minimum confirmation blocks for cross-chain messages
    uint256 public constant MIN_CONFIRMATION_BLOCKS = 12; // 12 blocks

    /**
     * @notice Chain configuration structure
     * @param chainId Chain identifier
     * @param name Human-readable chain name
     * @param isSupported Whether the chain is currently supported
     * @param bridgeAddress Bridge contract address on this chain
     * @param gasPrice Average gas price on this chain
     * @param blockTime Average block time in seconds
     * @param lastUpdateBlock Block number of last configuration update
     */
    struct ChainConfig {
        uint256 chainId;
        string name;
        bool isSupported;
        address bridgeAddress;
        uint256 gasPrice;
        uint256 blockTime;
        uint256 lastUpdateBlock;
    }

    /**
     * @notice Cross-chain message structure
     * @param sourceChain Source chain ID
     * @param targetChain Target chain ID
     * @param messageType Type of message (1 = state update, 2 = rebalancing, 3 = emergency)
     * @param payload Message payload
     * @param timestamp Message timestamp
     * @param nonce Message nonce for deduplication
     * @param signature Message signature
     */
    struct CrossChainMessage {
        uint256 sourceChain;
        uint256 targetChain;
        uint256 messageType;
        bytes payload;
        uint256 timestamp;
        uint256 nonce;
        bytes signature;
    }

    /**
     * @notice Calculate optimal gas price for cross-chain transaction
     * @param sourceChain Source chain configuration
     * @param targetChain Target chain configuration
     * @param urgency Urgency level (1-5, 5 being most urgent)
     * @return optimalGasPrice Optimal gas price in wei
     */
    function calculateOptimalGasPrice(
        ChainConfig memory sourceChain,
        ChainConfig memory targetChain,
        uint256 urgency
    ) internal pure returns (uint256 optimalGasPrice) {
        require(urgency >= 1 && urgency <= 5, "Invalid urgency level");
        
        // Base gas price from source chain
        uint256 baseGasPrice = sourceChain.gasPrice;
        
        // Adjust for urgency (1.1x to 2x multiplier)
        uint256 urgencyMultiplier = 10 + urgency; // 11 to 15
        optimalGasPrice = (baseGasPrice * urgencyMultiplier) / 10;
        
        // Adjust for target chain gas price if significantly different
        if (targetChain.gasPrice > 0) {
            uint256 gasPriceRatio = (targetChain.gasPrice * PRECISION) / sourceChain.gasPrice;
            
            // If target chain is much more expensive, increase gas price
            if (gasPriceRatio > 15e17) { // 1.5x more expensive
                optimalGasPrice = (optimalGasPrice * 12) / 10; // 20% increase
            }
        }
    }

    /**
     * @notice Calculate cross-chain transfer cost
     * @param amount Transfer amount
     * @param sourceChain Source chain configuration
     * @param targetChain Target chain configuration
     * @param bridgeFee Bridge fee percentage
     * @return totalCost Total cost including gas and bridge fees
     * @return gasCost Gas cost component
     * @return bridgeCost Bridge fee component
     */
    function calculateTransferCost(
        uint256 amount,
        ChainConfig memory sourceChain,
        ChainConfig memory targetChain,
        uint256 bridgeFee
    ) internal pure returns (
        uint256 totalCost,
        uint256 gasCost,
        uint256 bridgeCost
    ) {
        // Calculate gas cost (simplified estimation)
        uint256 gasLimit = 100000; // Estimated gas limit for cross-chain transfer
        gasCost = sourceChain.gasPrice * gasLimit;
        
        // Calculate bridge fee
        bridgeCost = (amount * bridgeFee) / PRECISION;
        
        // Total cost
        totalCost = gasCost + bridgeCost;
    }

    /**
     * @notice Validate cross-chain message
     * @param message Cross-chain message to validate
     * @param expectedSourceChain Expected source chain ID
     * @param currentBlock Current block number
     * @return isValid Whether the message is valid
     * @return errorCode Error code if invalid (0 = valid)
     */
    function validateCrossChainMessage(
        CrossChainMessage memory message,
        uint256 expectedSourceChain,
        uint256 currentBlock
    ) internal pure returns (bool isValid, uint256 errorCode) {
        // Check source chain
        if (message.sourceChain != expectedSourceChain) {
            return (false, 1); // Invalid source chain
        }
        
        // Check message age
        if (currentBlock - message.timestamp > MAX_MESSAGE_AGE) {
            return (false, 2); // Message too old
        }
        
        // Check payload length
        if (message.payload.length == 0) {
            return (false, 3); // Empty payload
        }
        
        // Check message type
        if (message.messageType == 0 || message.messageType > 3) {
            return (false, 4); // Invalid message type
        }
        
        // Check nonce (basic validation)
        if (message.nonce == 0) {
            return (false, 5); // Invalid nonce
        }
        
        // Check signature length (basic validation)
        if (message.signature.length != 65) {
            return (false, 6); // Invalid signature length
        }
        
        return (true, 0);
    }

    /**
     * @notice Calculate optimal rebalancing path
     * @param sourceChain Source chain ID
     * @param targetChain Target chain ID
     * @param amount Transfer amount
     * @param chainConfigs Array of chain configurations
     * @return path Optimal rebalancing path
     * @return totalCost Total cost for the path
     * @return estimatedTime Estimated time for completion
     */
    function calculateOptimalRebalancingPath(
        uint256 sourceChain,
        uint256 targetChain,
        uint256 amount,
        ChainConfig[] memory chainConfigs
    ) internal pure returns (
        uint256[] memory path,
        uint256 totalCost,
        uint256 estimatedTime
    ) {
        require(chainConfigs.length > 0, "No chain configurations");
        require(sourceChain != targetChain, "Source and target chains must be different");
        
        // Find source and target chain configs
        ChainConfig memory sourceConfig;
        ChainConfig memory targetConfig;
        bool sourceFound = false;
        bool targetFound = false;
        
        for (uint256 i = 0; i < chainConfigs.length; i++) {
            if (chainConfigs[i].chainId == sourceChain) {
                sourceConfig = chainConfigs[i];
                sourceFound = true;
            }
            if (chainConfigs[i].chainId == targetChain) {
                targetConfig = chainConfigs[i];
                targetFound = true;
            }
        }
        
        require(sourceFound && targetFound, "Chain configurations not found");
        require(sourceConfig.isSupported && targetConfig.isSupported, "Chains not supported");
        
        // Direct path (simplest case)
        if (_isDirectPathAvailable(sourceChain, targetChain, chainConfigs)) {
            path = new uint256[](2);
            path[0] = sourceChain;
            path[1] = targetChain;
            
            (totalCost, estimatedTime) = _calculateDirectPathCost(
                amount,
                sourceConfig,
                targetConfig
            );
        } else {
            // Find optimal multi-hop path
            (path, totalCost, estimatedTime) = _findOptimalMultiHopPath(
                sourceChain,
                targetChain,
                amount,
                chainConfigs
            );
        }
    }

    /**
     * @notice Calculate cross-chain latency
     * @param sourceChain Source chain configuration
     * @param targetChain Target chain configuration
     * @param messageType Type of message being sent
     * @return latency Estimated latency in blocks
     */
    function calculateCrossChainLatency(
        ChainConfig memory sourceChain,
        ChainConfig memory targetChain,
        uint256 messageType
    ) internal pure returns (uint256 latency) {
        // Base latency from source chain block time
        uint256 baseLatency = sourceChain.blockTime;
        
        // Add target chain confirmation time
        uint256 confirmationTime = targetChain.blockTime * MIN_CONFIRMATION_BLOCKS;
        
        // Base latency
        latency = baseLatency + confirmationTime;
        
        // Adjust for message type
        if (messageType == 1) { // State update
            latency = latency * 11 / 10; // 10% overhead
        } else if (messageType == 2) { // Rebalancing
            latency = latency * 12 / 10; // 20% overhead
        } else if (messageType == 3) { // Emergency
            latency = latency * 8 / 10; // 20% faster
        }
        
        // Convert to blocks (assuming 12s block time)
        latency = latency / 12;
    }

    /**
     * @notice Calculate optimal batch size for cross-chain operations
     * @param totalAmount Total amount to transfer
     * @param chainConfigs Array of chain configurations
     * @param maxBatchSize Maximum batch size
     * @return optimalBatchSize Optimal batch size
     * @return batchCount Number of batches needed
     */
    function calculateOptimalBatchSize(
        uint256 totalAmount,
        ChainConfig[] memory chainConfigs,
        uint256 maxBatchSize
    ) internal pure returns (uint256 optimalBatchSize, uint256 batchCount) {
        require(totalAmount > 0, "Total amount must be positive");
        require(maxBatchSize > 0, "Max batch size must be positive");
        
        // Calculate average gas price across chains
        uint256 totalGasPrice = 0;
        uint256 supportedChains = 0;
        
        for (uint256 i = 0; i < chainConfigs.length; i++) {
            if (chainConfigs[i].isSupported) {
                totalGasPrice += chainConfigs[i].gasPrice;
                supportedChains++;
            }
        }
        
        require(supportedChains > 0, "No supported chains");
        
        uint256 averageGasPrice = totalGasPrice / supportedChains;
        
        // Calculate optimal batch size based on gas efficiency
        // Larger batches are more gas efficient but have higher risk
        uint256 gasEfficiencyThreshold = 1000000; // 1M wei per operation
        
        if (averageGasPrice < gasEfficiencyThreshold) {
            // Low gas price - use larger batches
            optimalBatchSize = maxBatchSize;
        } else {
            // High gas price - use smaller batches
            optimalBatchSize = maxBatchSize / 2;
        }
        
        // Ensure minimum batch size
        optimalBatchSize = optimalBatchSize < 1000 ? 1000 : optimalBatchSize;
        
        // Calculate number of batches
        batchCount = (totalAmount + optimalBatchSize - 1) / optimalBatchSize;
    }

    /**
     * @notice Generate cross-chain message hash for signing
     * @param message Cross-chain message
     * @return messageHash Hash of the message
     */
    function generateMessageHash(
        CrossChainMessage memory message
    ) internal pure returns (bytes32 messageHash) {
        messageHash = keccak256(abi.encodePacked(
            message.sourceChain,
            message.targetChain,
            message.messageType,
            message.payload,
            message.timestamp,
            message.nonce
        ));
    }

    /**
     * @notice Calculate cross-chain message priority
     * @param message Cross-chain message
     * @param currentBlock Current block number
     * @return priority Priority score (higher = more urgent)
     */
    function calculateMessagePriority(
        CrossChainMessage memory message,
        uint256 currentBlock
    ) internal pure returns (uint256 priority) {
        // Base priority from message type
        if (message.messageType == 3) { // Emergency
            priority = 100;
        } else if (message.messageType == 2) { // Rebalancing
            priority = 70;
        } else if (message.messageType == 1) { // State update
            priority = 50;
        } else {
            priority = 10;
        }
        
        // Adjust for message age (older = higher priority)
        uint256 age = currentBlock - message.timestamp;
        if (age > 100) { // More than 100 blocks old
            priority = priority * 12 / 10; // 20% increase
        }
        
        // Adjust for payload size (larger = higher priority)
        if (message.payload.length > 1000) {
            priority = priority * 11 / 10; // 10% increase
        }
    }

    // ============ Internal Helper Functions ============

    function _isDirectPathAvailable(
        uint256 sourceChain,
        uint256 targetChain,
        ChainConfig[] memory chainConfigs
    ) internal pure returns (bool) {
        // Simplified check - in reality would check bridge connectivity
        for (uint256 i = 0; i < chainConfigs.length; i++) {
            if (chainConfigs[i].chainId == sourceChain && chainConfigs[i].isSupported) {
                return true; // Assume direct path available if source is supported
            }
        }
        return false;
    }

    function _calculateDirectPathCost(
        uint256 amount,
        ChainConfig memory sourceConfig,
        ChainConfig memory targetConfig
    ) internal pure returns (uint256 totalCost, uint256 estimatedTime) {
        // Calculate gas cost
        uint256 gasLimit = 100000;
        uint256 gasCost = sourceConfig.gasPrice * gasLimit;
        
        // Calculate bridge fee (simplified)
        uint256 bridgeFee = amount / 1000; // 0.1% bridge fee
        
        totalCost = gasCost + bridgeFee;
        
        // Estimate time
        estimatedTime = sourceConfig.blockTime + targetConfig.blockTime;
    }

    function _findOptimalMultiHopPath(
        uint256 sourceChain,
        uint256 targetChain,
        uint256 amount,
        ChainConfig[] memory chainConfigs
    ) internal pure returns (
        uint256[] memory path,
        uint256 totalCost,
        uint256 estimatedTime
    ) {
        // Simplified multi-hop path finding
        // In reality, this would use graph algorithms like Dijkstra
        
        // Find intermediate chains
        uint256[] memory intermediateChains = new uint256[](chainConfigs.length - 2);
        uint256 intermediateCount = 0;
        
        for (uint256 i = 0; i < chainConfigs.length; i++) {
            if (chainConfigs[i].chainId != sourceChain && 
                chainConfigs[i].chainId != targetChain && 
                chainConfigs[i].isSupported) {
                intermediateChains[intermediateCount] = chainConfigs[i].chainId;
                intermediateCount++;
            }
        }
        
        if (intermediateCount == 0) {
            // No intermediate chains available
            path = new uint256[](0);
            totalCost = 0;
            estimatedTime = 0;
            return (path, totalCost, estimatedTime);
        }
        
        // Use first available intermediate chain
        path = new uint256[](3);
        path[0] = sourceChain;
        path[1] = intermediateChains[0];
        path[2] = targetChain;
        
        // Calculate cost for multi-hop path
        totalCost = amount / 500; // 0.2% total fee for multi-hop
        estimatedTime = 300; // 5 minutes estimated
    }
}

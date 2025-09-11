// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {CrossChainUtils} from "./libraries/CrossChainUtils.sol";

/**
 * @title ChainRegistry
 * @notice Registry for supported chains and their configurations
 * @dev Manages chain configurations, bridge addresses, and network parameters
 */
contract ChainRegistry is Ownable, Pausable, ReentrancyGuard {
    using CrossChainUtils for CrossChainUtils.ChainConfig;

    /// @notice Maximum number of supported chains
    uint256 public constant MAX_CHAINS = 50;
    
    /// @notice Maximum chain name length
    uint256 public constant MAX_NAME_LENGTH = 32;
    
    /// @notice Minimum block time (1 second)
    uint256 public constant MIN_BLOCK_TIME = 1;
    
    /// @notice Maximum block time (30 seconds)
    uint256 public constant MAX_BLOCK_TIME = 30;

    /// @notice Mapping of chain ID to chain configuration
    mapping(uint256 => CrossChainUtils.ChainConfig) public chainConfigs;
    
    /// @notice Mapping of chain ID to supported status
    mapping(uint256 => bool) public supportedChains;
    
    /// @notice Array of all supported chain IDs
    uint256[] public supportedChainIds;
    
    /// @notice Mapping of chain ID to last update block
    mapping(uint256 => uint256) public lastUpdateBlocks;
    
    /// @notice Total number of supported chains
    uint256 public totalChains;

    /**
     * @notice Constructor
     */
    constructor() Ownable(msg.sender) {
        // Initialize with default values
        totalChains = 0;
    }

    /**
     * @notice Add a new supported chain
     * @param chainId Chain identifier
     * @param name Human-readable chain name
     * @param bridgeAddress Bridge contract address on this chain
     * @param gasPrice Average gas price on this chain (in wei)
     * @param blockTime Average block time in seconds
     */
    function addChain(
        uint256 chainId,
        string calldata name,
        address bridgeAddress,
        uint256 gasPrice,
        uint256 blockTime
    ) external onlyOwner {
        require(chainId != 0, "Invalid chain ID");
        require(bytes(name).length > 0 && bytes(name).length <= MAX_NAME_LENGTH, "Invalid name length");
        require(bridgeAddress != address(0), "Invalid bridge address");
        require(gasPrice > 0, "Invalid gas price");
        require(blockTime >= MIN_BLOCK_TIME && blockTime <= MAX_BLOCK_TIME, "Invalid block time");
        require(!supportedChains[chainId], "Chain already supported");
        require(totalChains < MAX_CHAINS, "Max chains reached");
        
        chainConfigs[chainId] = CrossChainUtils.ChainConfig({
            chainId: chainId,
            name: name,
            isSupported: true,
            bridgeAddress: bridgeAddress,
            gasPrice: gasPrice,
            blockTime: blockTime,
            lastUpdateBlock: block.number
        });
        
        supportedChains[chainId] = true;
        supportedChainIds.push(chainId);
        lastUpdateBlocks[chainId] = block.number;
        totalChains++;
        
        emit ChainAdded(chainId, name, bridgeAddress);
    }

    /**
     * @notice Remove a supported chain
     * @param chainId Chain identifier to remove
     */
    function removeChain(uint256 chainId) external onlyOwner {
        require(supportedChains[chainId], "Chain not supported");
        
        // Mark as not supported
        chainConfigs[chainId].isSupported = false;
        supportedChains[chainId] = false;
        
        // Remove from array
        for (uint256 i = 0; i < supportedChainIds.length; i++) {
            if (supportedChainIds[i] == chainId) {
                supportedChainIds[i] = supportedChainIds[supportedChainIds.length - 1];
                supportedChainIds.pop();
                break;
            }
        }
        
        totalChains--;
        
        emit ChainRemoved(chainId);
    }

    /**
     * @notice Update chain configuration
     * @param chainId Chain identifier
     * @param name New chain name
     * @param bridgeAddress New bridge address
     * @param gasPrice New gas price
     * @param blockTime New block time
     */
    function updateChainConfig(
        uint256 chainId,
        string calldata name,
        address bridgeAddress,
        uint256 gasPrice,
        uint256 blockTime
    ) external onlyOwner {
        require(supportedChains[chainId], "Chain not supported");
        require(bytes(name).length > 0 && bytes(name).length <= MAX_NAME_LENGTH, "Invalid name length");
        require(bridgeAddress != address(0), "Invalid bridge address");
        require(gasPrice > 0, "Invalid gas price");
        require(blockTime >= MIN_BLOCK_TIME && blockTime <= MAX_BLOCK_TIME, "Invalid block time");
        
        chainConfigs[chainId].name = name;
        chainConfigs[chainId].bridgeAddress = bridgeAddress;
        chainConfigs[chainId].gasPrice = gasPrice;
        chainConfigs[chainId].blockTime = blockTime;
        chainConfigs[chainId].lastUpdateBlock = block.number;
        lastUpdateBlocks[chainId] = block.number;
        
        emit ChainConfigUpdated(chainId, name, bridgeAddress, gasPrice, blockTime);
    }

    /**
     * @notice Update gas price for a chain
     * @param chainId Chain identifier
     * @param newGasPrice New gas price
     */
    function updateGasPrice(uint256 chainId, uint256 newGasPrice) external onlyOwner {
        require(supportedChains[chainId], "Chain not supported");
        require(newGasPrice > 0, "Invalid gas price");
        
        chainConfigs[chainId].gasPrice = newGasPrice;
        chainConfigs[chainId].lastUpdateBlock = block.number;
        lastUpdateBlocks[chainId] = block.number;
        
        emit GasPriceUpdated(chainId, newGasPrice);
    }

    /**
     * @notice Update bridge address for a chain
     * @param chainId Chain identifier
     * @param newBridgeAddress New bridge address
     */
    function updateBridgeAddress(uint256 chainId, address newBridgeAddress) external onlyOwner {
        require(supportedChains[chainId], "Chain not supported");
        require(newBridgeAddress != address(0), "Invalid bridge address");
        
        chainConfigs[chainId].bridgeAddress = newBridgeAddress;
        chainConfigs[chainId].lastUpdateBlock = block.number;
        lastUpdateBlocks[chainId] = block.number;
        
        emit BridgeAddressUpdated(chainId, newBridgeAddress);
    }

    /**
     * @notice Get chain configuration
     * @param chainId Chain identifier
     * @return config Chain configuration
     */
    function getChainConfig(uint256 chainId) external view returns (CrossChainUtils.ChainConfig memory config) {
        require(supportedChains[chainId], "Chain not supported");
        return chainConfigs[chainId];
    }

    /**
     * @notice Check if a chain is supported
     * @param chainId Chain identifier
     * @return supported True if chain is supported
     */
    function isChainSupported(uint256 chainId) external view returns (bool supported) {
        return supportedChains[chainId];
    }

    /**
     * @notice Get all supported chain IDs
     * @return chainIds Array of supported chain IDs
     */
    function getSupportedChainIds() external view returns (uint256[] memory chainIds) {
        return supportedChainIds;
    }

    /**
     * @notice Get all supported chain configurations
     * @return configs Array of chain configurations
     */
    function getAllChainConfigs() external view returns (CrossChainUtils.ChainConfig[] memory configs) {
        configs = new CrossChainUtils.ChainConfig[](supportedChainIds.length);
        
        for (uint256 i = 0; i < supportedChainIds.length; i++) {
            uint256 chainId = supportedChainIds[i];
            configs[i] = chainConfigs[chainId];
        }
        
        return configs;
    }

    /**
     * @notice Get chain count
     * @return count Number of supported chains
     */
    function getChainCount() external view returns (uint256 count) {
        return totalChains;
    }

    /**
     * @notice Get chain info by index
     * @param index Index in the supported chains array
     * @return chainId Chain ID
     * @return name Chain name
     * @return bridgeAddress Bridge address
     * @return gasPrice Gas price
     * @return blockTime Block time
     */
    function getChainByIndex(uint256 index) external view returns (
        uint256 chainId,
        string memory name,
        address bridgeAddress,
        uint256 gasPrice,
        uint256 blockTime
    ) {
        require(index < supportedChainIds.length, "Index out of bounds");
        
        uint256 id = supportedChainIds[index];
        CrossChainUtils.ChainConfig memory config = chainConfigs[id];
        
        return (
            config.chainId,
            config.name,
            config.bridgeAddress,
            config.gasPrice,
            config.blockTime
        );
    }

    /**
     * @notice Get chain statistics
     * @return totalChainsCount Total number of chains
     * @return activeChains Number of active chains
     * @return averageGasPrice Average gas price across chains
     * @return averageBlockTime Average block time across chains
     */
    function getChainStatistics() external view returns (
        uint256 totalChainsCount,
        uint256 activeChains,
        uint256 averageGasPrice,
        uint256 averageBlockTime
    ) {
        totalChainsCount = this.getChainCount();
        activeChains = 0;
        uint256 totalGasPrice = 0;
        uint256 totalBlockTime = 0;
        
        for (uint256 i = 0; i < supportedChainIds.length; i++) {
            uint256 chainId = supportedChainIds[i];
            CrossChainUtils.ChainConfig memory config = chainConfigs[chainId];
            
            if (config.isSupported) {
                activeChains++;
                totalGasPrice += config.gasPrice;
                totalBlockTime += config.blockTime;
            }
        }
        
        if (activeChains > 0) {
            averageGasPrice = totalGasPrice / activeChains;
            averageBlockTime = totalBlockTime / activeChains;
        }
        
        return (totalChains, activeChains, averageGasPrice, averageBlockTime);
    }

    /**
     * @notice Check if chain configuration is up to date
     * @param chainId Chain identifier
     * @param maxAge Maximum age in blocks
     * @return isUpToDate True if configuration is up to date
     */
    function isConfigUpToDate(uint256 chainId, uint256 maxAge) external view returns (bool isUpToDate) {
        if (!supportedChains[chainId]) return false;
        
        uint256 lastUpdate = lastUpdateBlocks[chainId];
        return block.number - lastUpdate <= maxAge;
    }

    /**
     * @notice Get optimal chain for a specific operation
     * @param operationType Type of operation (1 = low cost, 2 = fast, 3 = balanced)
     * @return optimalChainId Optimal chain ID
     */
    function getOptimalChain(uint256 operationType) external view returns (uint256 optimalChainId) {
        require(operationType >= 1 && operationType <= 3, "Invalid operation type");
        require(totalChains > 0, "No chains available");
        
        uint256 bestScore = type(uint256).max;
        uint256 bestChainId = 0;
        
        for (uint256 i = 0; i < supportedChainIds.length; i++) {
            uint256 chainId = supportedChainIds[i];
            CrossChainUtils.ChainConfig memory config = chainConfigs[chainId];
            
            if (!config.isSupported) continue;
            
            uint256 score = 0;
            
            if (operationType == 1) { // Low cost
                score = config.gasPrice;
            } else if (operationType == 2) { // Fast
                score = config.blockTime;
            } else { // Balanced
                score = (config.gasPrice * config.blockTime) / 1e18;
            }
            
            if (score < bestScore) {
                bestScore = score;
                bestChainId = chainId;
            }
        }
        
        return bestChainId;
    }

    /**
     * @notice Emergency pause
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Emergency unpause
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ Events ============

    event ChainAdded(uint256 indexed chainId, string name, address bridgeAddress);
    event ChainRemoved(uint256 indexed chainId);
    event ChainConfigUpdated(uint256 indexed chainId, string name, address bridgeAddress, uint256 gasPrice, uint256 blockTime);
    event GasPriceUpdated(uint256 indexed chainId, uint256 newGasPrice);
    event BridgeAddressUpdated(uint256 indexed chainId, address newBridgeAddress);
}

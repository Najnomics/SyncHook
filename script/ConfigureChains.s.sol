// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console2} from "forge-std/Script.sol";
import {ChainRegistry} from "../src/integration/ChainRegistry.sol";
import {StateOracles} from "../src/integration/StateOracles.sol";
import {AcrossIntegration} from "../src/integration/AcrossIntegration.sol";

contract ConfigureChainsScript is Script {
    // Contract addresses (will be set via environment variables)
    address public chainRegistry;
    address public stateOracles;
    address public acrossIntegration;

    // Chain configurations
    struct ChainConfig {
        uint256 chainId;
        string name;
        bool isActive;
        uint256 weight;
        address rpcUrl;
        address bridgeAddress;
        address[] tokens;
        address[] priceFeeds;
    }

    ChainConfig[] public chains;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get contract addresses from environment variables
        chainRegistry = vm.envAddress("CHAIN_REGISTRY_ADDRESS");
        stateOracles = vm.envAddress("STATE_ORACLES_ADDRESS");
        acrossIntegration = vm.envAddress("ACROSS_INTEGRATION_ADDRESS");

        console2.log("Configuring chains with account:", deployer);
        console2.log("ChainRegistry address:", chainRegistry);
        console2.log("StateOracles address:", stateOracles);
        console2.log("AcrossIntegration address:", acrossIntegration);

        vm.startBroadcast(deployerPrivateKey);

        // Initialize chain configurations
        _initializeChainConfigs();

        // Configure each chain
        for (uint256 i = 0; i < chains.length; i++) {
            console2.log("Configuring chain:", chains[i].name);
            _configureChain(chains[i]);
        }

        // Setup cross-chain connections
        console2.log("Setting up cross-chain connections...");
        _setupCrossChainConnections();

        vm.stopBroadcast();

        console2.log("Chain configuration completed successfully!");
    }

    function _initializeChainConfigs() internal {
        // Ethereum Mainnet
        chains.push(ChainConfig({
            chainId: 1,
            name: "Ethereum",
            isActive: true,
            weight: 0.4e18, // 40%
            rpcUrl: address(0), // Will be set via environment
            bridgeAddress: address(0), // Will be set via environment
            tokens: new address[](0), // Will be populated
            priceFeeds: new address[](0) // Will be populated
        }));

        // Polygon
        chains.push(ChainConfig({
            chainId: 137,
            name: "Polygon",
            isActive: true,
            weight: 0.3e18, // 30%
            rpcUrl: address(0), // Will be set via environment
            bridgeAddress: address(0), // Will be set via environment
            tokens: new address[](0), // Will be populated
            priceFeeds: new address[](0) // Will be populated
        }));

        // Arbitrum
        chains.push(ChainConfig({
            chainId: 42161,
            name: "Arbitrum",
            isActive: true,
            weight: 0.3e18, // 30%
            rpcUrl: address(0), // Will be set via environment
            bridgeAddress: address(0), // Will be set via environment
            tokens: new address[](0), // Will be populated
            priceFeeds: new address[](0) // Will be populated
        }));

        // Optimism
        chains.push(ChainConfig({
            chainId: 10,
            name: "Optimism",
            isActive: true,
            weight: 0.2e18, // 20%
            rpcUrl: address(0), // Will be set via environment
            bridgeAddress: address(0), // Will be set via environment
            tokens: new address[](0), // Will be populated
            priceFeeds: new address[](0) // Will be populated
        }));

        // Base
        chains.push(ChainConfig({
            chainId: 8453,
            name: "Base",
            isActive: true,
            weight: 0.1e18, // 10%
            rpcUrl: address(0), // Will be set via environment
            bridgeAddress: address(0), // Will be set via environment
            tokens: new address[](0), // Will be populated
            priceFeeds: new address[](0) // Will be populated
        }));
    }

    function _configureChain(ChainConfig memory config) internal {
        ChainRegistry registry = ChainRegistry(chainRegistry);
        StateOracles oracles = StateOracles(stateOracles);

        // Add chain to registry
        registry.addChain(
            config.chainId,
            config.name,
            config.bridgeAddress,
            20000000000, // gasPrice: 20 gwei
            12 // blockTime: 12 seconds
        );
        console2.log("Added chain to registry:", config.name);

        // Update bridge address if provided
        if (config.bridgeAddress != address(0)) {
            registry.updateBridgeAddress(config.chainId, config.bridgeAddress);
            console2.log("Set bridge address for chain:", config.name);
        }

        // Configure tokens and price feeds
        for (uint256 i = 0; i < config.tokens.length; i++) {
            if (config.tokens[i] != address(0) && config.priceFeeds[i] != address(0)) {
                // First authorize the oracle
                oracles.authorizeOracle(config.priceFeeds[i]);
                // Then add it for the token
                oracles.addOracle(
                    config.tokens[i],
                    config.priceFeeds[i],
                    1e18, // weight: 1.0
                    8 // decimals: 8 (typical for price feeds)
                );
                console2.log("Added price feed for token:", config.tokens[i], "on chain:", config.name);
            }
        }

        // Update gas price for the chain
        registry.updateGasPrice(config.chainId, 20000000000); // 20 gwei
        console2.log("Set gas price for:", config.name);
    }

    function _setupCrossChainConnections() internal {
        AcrossIntegration across = AcrossIntegration(acrossIntegration);

        // Configure cross-chain routes
        _configureCrossChainRoute(1, 137, 0.95e18); // Ethereum -> Polygon: 95% efficiency
        _configureCrossChainRoute(1, 42161, 0.98e18); // Ethereum -> Arbitrum: 98% efficiency
        _configureCrossChainRoute(1, 10, 0.97e18); // Ethereum -> Optimism: 97% efficiency
        _configureCrossChainRoute(1, 8453, 0.96e18); // Ethereum -> Base: 96% efficiency
        _configureCrossChainRoute(137, 42161, 0.93e18); // Polygon -> Arbitrum: 93% efficiency
        _configureCrossChainRoute(137, 10, 0.92e18); // Polygon -> Optimism: 92% efficiency
        _configureCrossChainRoute(137, 8453, 0.91e18); // Polygon -> Base: 91% efficiency
        _configureCrossChainRoute(42161, 10, 0.94e18); // Arbitrum -> Optimism: 94% efficiency
        _configureCrossChainRoute(42161, 8453, 0.93e18); // Arbitrum -> Base: 93% efficiency
        _configureCrossChainRoute(10, 8453, 0.92e18); // Optimism -> Base: 92% efficiency

        console2.log("Cross-chain routes configured");
    }

    function _configureCrossChainRoute(uint256 sourceChain, uint256 targetChain, uint256 efficiency) internal {
        AcrossIntegration across = AcrossIntegration(acrossIntegration);
        
        // Add supported chains
        across.addSupportedChain(sourceChain);
        across.addSupportedChain(targetChain);
        console2.log("Added supported chains:", sourceChain, "and", targetChain);

        // Update configuration
        across.updateAcrossConfig(
            10, // bridgeFeeBps: 0.1%
            1000000e18, // maxRebalancingAmount: 1M tokens
            1000e18, // minRebalancingAmount: 1K tokens
            100 // rebalancingCooldown: 100 blocks
        );
        console2.log("Updated Across configuration");
    }
}

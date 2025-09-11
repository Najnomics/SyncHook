// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {ChainRegistry} from "../../src/integration/ChainRegistry.sol";
import {CrossChainUtils} from "../../src/integration/libraries/CrossChainUtils.sol";

contract ChainRegistryTest is Test {
    ChainRegistry public chainRegistry;
    
    address public owner = address(0x1);
    address public user = address(0x2);
    
    function setUp() public {
        vm.prank(owner);
        chainRegistry = new ChainRegistry();
    }
    
    function test_Deployment() public {
        assertTrue(address(chainRegistry) != address(0));
        assertEq(chainRegistry.owner(), owner);
        assertEq(chainRegistry.totalChains(), 0);
    }
    
    function test_AddChain() public {
        vm.prank(owner);
        chainRegistry.addChain(
            1, // chainId: Ethereum
            "Ethereum",
            address(0x1000), // bridgeAddress
            20000000000, // gasPrice: 20 gwei
            12 // blockTime: 12 seconds
        );
        
        assertTrue(chainRegistry.isChainSupported(1));
        assertEq(chainRegistry.totalChains(), 1);
        
        // Check chain details
        (
            uint256 chainId,
            string memory name,
            address bridgeAddress,
            uint256 gasPrice,
            uint256 blockTime
        ) = chainRegistry.getChainByIndex(0);
        
        assertEq(chainId, 1);
        assertEq(name, "Ethereum");
        assertEq(bridgeAddress, address(0x1000));
        assertEq(gasPrice, 20000000000);
        assertEq(blockTime, 12);
    }
    
    function test_AddChainInvalidChainId() public {
        vm.expectRevert("Invalid chain ID");
        vm.prank(owner);
        chainRegistry.addChain(
            0, // invalid chainId
            "Ethereum",
            address(0x1000),
            20000000000,
            12
        );
    }
    
    function test_AddChainInvalidName() public {
        vm.expectRevert("Invalid name length");
        vm.prank(owner);
        chainRegistry.addChain(
            1,
            "", // empty name
            address(0x1000),
            20000000000,
            12
        );
    }
    
    function test_AddChainInvalidBridgeAddress() public {
        vm.expectRevert("Invalid bridge address");
        vm.prank(owner);
        chainRegistry.addChain(
            1,
            "Ethereum",
            address(0), // invalid bridge address
            20000000000,
            12
        );
    }
    
    function test_AddChainInvalidGasPrice() public {
        vm.expectRevert("Invalid gas price");
        vm.prank(owner);
        chainRegistry.addChain(
            1,
            "Ethereum",
            address(0x1000),
            0, // invalid gas price
            12
        );
    }
    
    function test_AddChainInvalidBlockTime() public {
        vm.expectRevert("Invalid block time");
        vm.prank(owner);
        chainRegistry.addChain(
            1,
            "Ethereum",
            address(0x1000),
            20000000000,
            0 // invalid block time
        );
    }
    
    function test_AddChainAlreadySupported() public {
        vm.prank(owner);
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
        
        vm.expectRevert("Chain already supported");
        vm.prank(owner);
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
    }
    
    function test_RemoveChain() public {
        vm.prank(owner);
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
        assertTrue(chainRegistry.isChainSupported(1));
        assertEq(chainRegistry.totalChains(), 1);
        
        vm.prank(owner);
        chainRegistry.removeChain(1);
        assertFalse(chainRegistry.isChainSupported(1));
        assertEq(chainRegistry.totalChains(), 0);
    }
    
    function test_RemoveChainNotSupported() public {
        vm.expectRevert("Chain not supported");
        vm.prank(owner);
        chainRegistry.removeChain(1);
    }
    
    function test_UpdateChainConfig() public {
        vm.prank(owner);
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
        
        vm.prank(owner);
        chainRegistry.updateChainConfig(
            1,
            "Ethereum Mainnet", // new name
            address(0x2000), // new bridge address
            30000000000, // new gas price: 30 gwei
            15 // new block time: 15 seconds
        );
        
        // Check updated config
        (
            uint256 chainId,
            string memory name,
            address bridgeAddress,
            uint256 gasPrice,
            uint256 blockTime
        ) = chainRegistry.getChainByIndex(0);
        
        assertEq(chainId, 1);
        assertEq(name, "Ethereum Mainnet");
        assertEq(bridgeAddress, address(0x2000));
        assertEq(gasPrice, 30000000000);
        assertEq(blockTime, 15);
    }
    
    function test_UpdateGasPrice() public {
        vm.prank(owner);
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
        
        vm.prank(owner);
        chainRegistry.updateGasPrice(1, 25000000000); // 25 gwei
        
        CrossChainUtils.ChainConfig memory config = chainRegistry.getChainConfig(1);
        assertEq(config.gasPrice, 25000000000);
    }
    
    function test_UpdateBridgeAddress() public {
        vm.prank(owner);
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
        
        vm.prank(owner);
        chainRegistry.updateBridgeAddress(1, address(0x3000));
        
        CrossChainUtils.ChainConfig memory config = chainRegistry.getChainConfig(1);
        assertEq(config.bridgeAddress, address(0x3000));
    }
    
    function test_GetChainConfig() public {
        vm.prank(owner);
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
        
        CrossChainUtils.ChainConfig memory config = chainRegistry.getChainConfig(1);
        assertEq(config.chainId, 1);
        assertEq(config.name, "Ethereum");
        assertEq(config.bridgeAddress, address(0x1000));
        assertEq(config.gasPrice, 20000000000);
        assertEq(config.blockTime, 12);
        assertTrue(config.isSupported);
    }
    
    function test_GetSupportedChainIds() public {
        vm.prank(owner);
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
        vm.prank(owner);
        chainRegistry.addChain(137, "Polygon", address(0x2000), 30000000000, 2);
        
        uint256[] memory chainIds = chainRegistry.getSupportedChainIds();
        assertEq(chainIds.length, 2);
        assertEq(chainIds[0], 1);
        assertEq(chainIds[1], 137);
    }
    
    function test_GetAllChainConfigs() public {
        vm.prank(owner);
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
        vm.prank(owner);
        chainRegistry.addChain(137, "Polygon", address(0x2000), 30000000000, 2);
        
        CrossChainUtils.ChainConfig[] memory configs = chainRegistry.getAllChainConfigs();
        assertEq(configs.length, 2);
        assertEq(configs[0].chainId, 1);
        assertEq(configs[1].chainId, 137);
    }
    
    function test_GetChainCount() public {
        assertEq(chainRegistry.getChainCount(), 0);
        
        vm.prank(owner);
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
        assertEq(chainRegistry.getChainCount(), 1);
        
        vm.prank(owner);
        chainRegistry.addChain(137, "Polygon", address(0x2000), 30000000000, 2);
        assertEq(chainRegistry.getChainCount(), 2);
    }
    
    function test_GetChainStatistics() public {
        vm.prank(owner);
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
        vm.prank(owner);
        chainRegistry.addChain(137, "Polygon", address(0x2000), 30000000000, 2);
        
        (
            uint256 totalChains,
            uint256 activeChains,
            uint256 averageGasPrice,
            uint256 averageBlockTime
        ) = chainRegistry.getChainStatistics();
        
        assertEq(totalChains, 2);
        assertEq(activeChains, 2);
        assertEq(averageGasPrice, 25000000000); // (20 + 30) / 2 = 25 gwei
        assertEq(averageBlockTime, 7); // (12 + 2) / 2 = 7 seconds
    }
    
    function test_IsConfigUpToDate() public {
        vm.prank(owner);
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
        
        bool isUpToDate = chainRegistry.isConfigUpToDate(1, 100);
        assertTrue(isUpToDate);
        
        // Fast forward blocks
        vm.roll(block.number + 150);
        isUpToDate = chainRegistry.isConfigUpToDate(1, 100);
        assertFalse(isUpToDate);
    }
    
    function test_GetOptimalChain() public {
        vm.prank(owner);
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
        vm.prank(owner);
        chainRegistry.addChain(137, "Polygon", address(0x2000), 10000000000, 2);
        
        // Low cost operation (should choose Polygon with lower gas price)
        uint256 optimalChain = chainRegistry.getOptimalChain(1);
        assertEq(optimalChain, 137);
        
        // Fast operation (should choose Polygon with lower block time)
        optimalChain = chainRegistry.getOptimalChain(2);
        assertEq(optimalChain, 137);
        
        // Balanced operation
        optimalChain = chainRegistry.getOptimalChain(3);
        assertTrue(optimalChain == 1 || optimalChain == 137);
    }
    
    function test_GetOptimalChainInvalidType() public {
        vm.expectRevert("Invalid operation type");
        chainRegistry.getOptimalChain(0);
    }
    
    function test_GetOptimalChainNoChains() public {
        vm.expectRevert("No chains available");
        chainRegistry.getOptimalChain(1);
    }
    
    function test_Pause() public {
        vm.prank(owner);
        chainRegistry.pause();
        // Should not revert
    }
    
    function test_Unpause() public {
        vm.prank(owner);
        chainRegistry.pause();
        vm.prank(owner);
        chainRegistry.unpause();
        // Should not revert
    }
    
    function test_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        chainRegistry.addChain(1, "Ethereum", address(0x1000), 20000000000, 12);
    }
    
    function test_IndexOutOfBounds() public {
        vm.expectRevert("Index out of bounds");
        chainRegistry.getChainByIndex(0);
    }
    
    function test_ChainNotSupported() public {
        vm.expectRevert("Chain not supported");
        chainRegistry.getChainConfig(1);
    }
}

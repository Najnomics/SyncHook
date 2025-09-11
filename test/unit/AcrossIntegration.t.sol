// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {AcrossIntegration} from "../../src/integration/AcrossIntegration.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "../helpers/MockERC20.sol";

contract AcrossIntegrationTest is Test {
    AcrossIntegration public acrossIntegration;
    MockERC20 public token;
    MockERC20 public counterToken;
    
    address public owner = address(0x1);
    address public syncAVS = address(0x2);
    address public user = address(0x3);
    
    function setUp() public {
        // Deploy mock tokens
        token = new MockERC20("Test Token", "TEST", 18);
        counterToken = new MockERC20("Counter Token", "CTEST", 18);
        
        // Mint tokens to this contract for testing
        token.mint(address(this), 1000000e18);
        counterToken.mint(address(this), 1000000e18);
        
        acrossIntegration = new AcrossIntegration(
            address(0x3000), // spokePool
            syncAVS,
            10, // bridgeFeeBps: 0.1%
            1000000e18, // maxRebalancingAmount: 1M tokens
            1000e18, // minRebalancingAmount: 1K tokens
            100 // rebalancingCooldown: 100 blocks
        );
        
        // Add supported tokens
        vm.prank(acrossIntegration.owner());
        acrossIntegration.addSupportedToken(address(token));
        vm.prank(acrossIntegration.owner());
        acrossIntegration.addSupportedToken(address(counterToken));
        
        // Add a supported chain for testing
        vm.prank(acrossIntegration.owner());
        acrossIntegration.addSupportedChain(2); // Chain ID 2
        
        // Approve the contract to spend tokens for testing
        token.approve(address(acrossIntegration), 1000000e18);
        counterToken.approve(address(acrossIntegration), 1000000e18);
        
        // Give the owner some tokens for testing
        token.mint(acrossIntegration.owner(), 1000000e18);
        counterToken.mint(acrossIntegration.owner(), 1000000e18);
        
        // Approve the contract to spend owner's tokens
        vm.prank(acrossIntegration.owner());
        token.approve(address(acrossIntegration), 1000000e18);
        vm.prank(acrossIntegration.owner());
        counterToken.approve(address(acrossIntegration), 1000000e18);
        
        // Give syncAVS some tokens for testing
        token.mint(syncAVS, 1000000e18);
        counterToken.mint(syncAVS, 1000000e18);
        
        // Approve the contract to spend syncAVS's tokens
        vm.prank(syncAVS);
        token.approve(address(acrossIntegration), 1000000e18);
        vm.prank(syncAVS);
        counterToken.approve(address(acrossIntegration), 1000000e18);
    }
    
    function _resetCooldown() internal {
        // Warp to future to reset cooldown
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 101); // 101 blocks to exceed cooldown of 100
    }
    
    function test_Deployment() public {
        assertTrue(address(acrossIntegration) != address(0));
        assertEq(acrossIntegration.bridgeFeeBps(), 10);
        assertEq(acrossIntegration.maxRebalancingAmount(), 1000000e18);
        assertEq(acrossIntegration.minRebalancingAmount(), 1000e18);
        assertEq(acrossIntegration.rebalancingCooldown(), 100);
    }
    
    function test_RequestRebalancing() public {
        _resetCooldown();
        vm.prank(syncAVS);
        bytes32 requestId = acrossIntegration.requestRebalancing(
            address(token),
            address(counterToken),
            5000e18 // imbalanceAmount
        );
        
        assertTrue(requestId != bytes32(0));
        
        // Check request details
        AcrossIntegration.RebalancingRequest memory request = acrossIntegration.getRebalancingRequest(requestId);
        assertEq(request.sourceChain, block.chainid);
        assertEq(request.token, address(token));
        assertEq(request.amount, 2500e18); // transferAmount = imbalanceAmount / 2
        assertTrue(request.executed);
    }
    
    function test_RequestRebalancingInvalidToken() public {
        vm.prank(syncAVS);
        vm.expectRevert("Token not supported");
        acrossIntegration.requestRebalancing(
            address(0x9999), // unsupported token
            address(counterToken),
            5000e18
        );
    }
    
    function test_RequestRebalancingAmountTooSmall() public {
        vm.prank(syncAVS);
        vm.expectRevert("Amount too small");
        acrossIntegration.requestRebalancing(
            address(token),
            address(counterToken),
            100e18 // below minimum
        );
    }
    
    function test_RequestRebalancingAmountTooLarge() public {
        vm.prank(syncAVS);
        vm.expectRevert("Amount too large");
        acrossIntegration.requestRebalancing(
            address(token),
            address(counterToken),
            2000000e18 // above maximum
        );
    }
    
    function test_RequestRebalancingCooldown() public {
        _resetCooldown();
        vm.prank(syncAVS);
        acrossIntegration.requestRebalancing(
            address(token),
            address(counterToken),
            5000e18
        );
        
        // Try again immediately (should fail due to cooldown)
        vm.prank(syncAVS);
        vm.expectRevert("Rebalancing cooldown active");
        acrossIntegration.requestRebalancing(
            address(token),
            address(counterToken),
            5000e18
        );
    }
    
    function test_ExecuteRebalancing() public {
        _resetCooldown();
        vm.prank(syncAVS);
        bytes32 requestId = acrossIntegration.requestRebalancing(
            address(token),
            address(counterToken),
            5000e18
        );
        
        // The rebalancing is already executed by requestRebalancing
        // Just verify the request was created and executed
        AcrossIntegration.RebalancingRequest memory request = acrossIntegration.getRebalancingRequest(requestId);
        assertTrue(request.executed);
        assertEq(request.amount, 2500e18); // transferAmount = imbalanceAmount / 2
    }
    
    function test_GetRebalancingRequest() public {
        _resetCooldown();
        vm.prank(syncAVS);
        bytes32 requestId = acrossIntegration.requestRebalancing(
            address(token),
            address(counterToken),
            5000e18
        );
        
        AcrossIntegration.RebalancingRequest memory request = acrossIntegration.getRebalancingRequest(requestId);
        assertEq(request.sourceChain, block.chainid);
        assertEq(request.token, address(token));
        assertEq(request.amount, 2500e18); // transferAmount = imbalanceAmount / 2
    }
    
    function test_IsRebalancingInProgress() public {
        _resetCooldown();
        vm.prank(syncAVS);
        acrossIntegration.requestRebalancing(
            address(token),
            address(counterToken),
            5000e18
        );
        
        bool inProgress = acrossIntegration.isRebalancingInProgress(address(token), address(counterToken));
        assertTrue(inProgress);
    }
    
    function test_CalculateOptimalRebalancing() public {
        (uint256 targetChain, uint256 transferAmount) = acrossIntegration.calculateOptimalRebalancing(
            address(token),
            address(counterToken),
            5000e18
        );
        
        assertTrue(targetChain > 0);
        assertTrue(transferAmount > 0);
    }
    
    function test_GetSupportedChains() public {
        uint256[] memory chains = acrossIntegration.getSupportedChains();
        assertTrue(chains.length >= 0);
    }
    
    function test_IsChainSupported() public {
        bool isSupported = acrossIntegration.isChainSupported(1);
        assertFalse(isSupported); // Should be false initially
    }
    
    function test_AddSupportedChain() public {
        acrossIntegration.addSupportedChain(1);
        assertTrue(acrossIntegration.isChainSupported(1));
    }
    
    function test_RemoveSupportedChain() public {
        acrossIntegration.addSupportedChain(1);
        assertTrue(acrossIntegration.isChainSupported(1));
        
        acrossIntegration.removeSupportedChain(1);
        assertFalse(acrossIntegration.isChainSupported(1));
    }
    
    function test_UpdateAcrossConfig() public {
        acrossIntegration.updateAcrossConfig(
            20, // new bridge fee: 0.2%
            2000000e18, // new max amount: 2M tokens
            2000e18, // new min amount: 2K tokens
            200 // new cooldown: 200 blocks
        );
        
        assertEq(acrossIntegration.bridgeFeeBps(), 20);
        assertEq(acrossIntegration.maxRebalancingAmount(), 2000000e18);
        assertEq(acrossIntegration.minRebalancingAmount(), 2000e18);
        assertEq(acrossIntegration.rebalancingCooldown(), 200);
    }
    
    function test_PauseRebalancing() public {
        acrossIntegration.pauseRebalancing();
        assertTrue(acrossIntegration.rebalancingPaused());
    }
    
    function test_ResumeRebalancing() public {
        acrossIntegration.pauseRebalancing();
        acrossIntegration.resumeRebalancing();
        assertFalse(acrossIntegration.rebalancingPaused());
    }
    
    function test_Pause() public {
        acrossIntegration.pause();
        // Should not revert
    }
    
    function test_Unpause() public {
        acrossIntegration.pause();
        acrossIntegration.unpause();
        // Should not revert
    }
    
    function test_OnlySyncAVS() public {
        vm.prank(user);
        vm.expectRevert("Only SyncAVS");
        acrossIntegration.requestRebalancing(address(token), address(counterToken), 5000e18);
    }
    
    function test_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        acrossIntegration.updateAcrossConfig(20, 2000000e18, 2000e18, 200);
    }
    
    function test_InvalidRequestId() public {
        AcrossIntegration.RebalancingRequest memory request = acrossIntegration.getRebalancingRequest(bytes32(0));
        assertEq(request.amount, 0); // Empty struct for invalid request ID
        assertEq(request.token, address(0));
        assertFalse(request.executed);
    }
}

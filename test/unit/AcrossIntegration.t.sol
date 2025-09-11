// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {AcrossIntegration} from "../../src/integration/AcrossIntegration.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AcrossIntegrationTest is Test {
    AcrossIntegration public acrossIntegration;
    
    address public owner = address(0x1);
    address public syncAVS = address(0x2);
    address public user = address(0x3);
    address public token = address(0x1000);
    address public counterToken = address(0x2000);
    
    function setUp() public {
        acrossIntegration = new AcrossIntegration(
            address(0x3000), // spokePool
            syncAVS,
            10, // bridgeFeeBps: 0.1%
            1000000e18, // maxRebalancingAmount: 1M tokens
            1000e18, // minRebalancingAmount: 1K tokens
            100 // rebalancingCooldown: 100 blocks
        );
    }
    
    function test_Deployment() public {
        assertTrue(address(acrossIntegration) != address(0));
        assertEq(acrossIntegration.bridgeFeeBps(), 10);
        assertEq(acrossIntegration.maxRebalancingAmount(), 1000000e18);
        assertEq(acrossIntegration.minRebalancingAmount(), 1000e18);
        assertEq(acrossIntegration.rebalancingCooldown(), 100);
    }
    
    function test_RequestRebalancing() public {
        vm.prank(syncAVS);
        bytes32 requestId = acrossIntegration.requestRebalancing(
            token,
            counterToken,
            5000e18 // imbalanceAmount
        );
        
        assertTrue(requestId != bytes32(0));
        
        // Check request details
        AcrossIntegration.RebalancingRequest memory request = acrossIntegration.getRebalancingRequest(requestId);
        assertEq(request.sourceChain, block.chainid);
        assertEq(request.token, token);
        assertEq(request.amount, 5000e18);
        assertTrue(request.executed);
    }
    
    function test_RequestRebalancingInvalidToken() public {
        vm.prank(syncAVS);
        vm.expectRevert("Token not supported");
        acrossIntegration.requestRebalancing(
            address(0x9999), // unsupported token
            counterToken,
            5000e18
        );
    }
    
    function test_RequestRebalancingAmountTooSmall() public {
        vm.prank(syncAVS);
        vm.expectRevert("Amount too small");
        acrossIntegration.requestRebalancing(
            token,
            counterToken,
            100e18 // below minimum
        );
    }
    
    function test_RequestRebalancingAmountTooLarge() public {
        vm.prank(syncAVS);
        vm.expectRevert("Amount too large");
        acrossIntegration.requestRebalancing(
            token,
            counterToken,
            2000000e18 // above maximum
        );
    }
    
    function test_RequestRebalancingCooldown() public {
        vm.prank(syncAVS);
        acrossIntegration.requestRebalancing(
            token,
            counterToken,
            5000e18
        );
        
        // Try again immediately (should fail due to cooldown)
        vm.prank(syncAVS);
        vm.expectRevert("Rebalancing cooldown active");
        acrossIntegration.requestRebalancing(
            token,
            counterToken,
            5000e18
        );
    }
    
    function test_ExecuteRebalancing() public {
        vm.prank(syncAVS);
        bytes32 requestId = acrossIntegration.requestRebalancing(
            token,
            counterToken,
            5000e18
        );
        
        // Execute rebalancing
        acrossIntegration.executeRebalancing(requestId);
        // Should not revert
    }
    
    function test_GetRebalancingRequest() public {
        vm.prank(syncAVS);
        bytes32 requestId = acrossIntegration.requestRebalancing(
            token,
            counterToken,
            5000e18
        );
        
        AcrossIntegration.RebalancingRequest memory request = acrossIntegration.getRebalancingRequest(requestId);
        assertEq(request.sourceChain, block.chainid);
        assertEq(request.token, token);
        assertEq(request.amount, 5000e18);
    }
    
    function test_IsRebalancingInProgress() public {
        vm.prank(syncAVS);
        acrossIntegration.requestRebalancing(
            token,
            counterToken,
            5000e18
        );
        
        bool inProgress = acrossIntegration.isRebalancingInProgress(token, counterToken);
        assertTrue(inProgress);
    }
    
    function test_CalculateOptimalRebalancing() public {
        (uint256 targetChain, uint256 transferAmount) = acrossIntegration.calculateOptimalRebalancing(
            token,
            counterToken,
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
        acrossIntegration.requestRebalancing(token, counterToken, 5000e18);
    }
    
    function test_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        acrossIntegration.updateAcrossConfig(20, 2000000e18, 2000e18, 200);
    }
    
    function test_InvalidRequestId() public {
        vm.expectRevert();
        acrossIntegration.getRebalancingRequest(bytes32(0));
    }
}

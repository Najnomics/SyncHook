// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console2} from "forge-std/Test.sol";
import {StateOracles} from "../../src/integration/StateOracles.sol";

contract StateOraclesTest is Test {
    StateOracles public stateOracles;
    
    address public owner = address(0x1);
    address public user = address(0x2);
    address public token = address(0x1000);
    address public oracle = address(0x2000);
    
    function setUp() public {
        vm.prank(owner);
        stateOracles = new StateOracles();
    }
    
    function test_Deployment() public {
        assertTrue(address(stateOracles) != address(0));
        assertEq(stateOracles.owner(), owner);
    }
    
    function test_AddOracle() public {
        // First authorize the oracle
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        
        // Add oracle for token
        vm.prank(owner);
        stateOracles.addOracle(
            token,
            oracle,
            1e18, // weight
            8 // decimals
        );
        
        // Check if token is supported
        assertTrue(stateOracles.isTokenSupported(token));
        
        // Check oracle count
        StateOracles.OracleConfig[] memory oracles = stateOracles.getTokenOracles(token);
        assertEq(oracles.length, 1);
        assertEq(oracles[0].oracleAddress, oracle);
        assertEq(oracles[0].weight, 1e18);
        assertEq(oracles[0].decimals, 8);
        assertTrue(oracles[0].isActive);
    }
    
    function test_AddOracleUnauthorized() public {
        vm.expectRevert("Oracle not authorized");
        vm.prank(owner);
        stateOracles.addOracle(
            token,
            oracle,
            1e18,
            8
        );
    }
    
    function test_AddOracleInvalidToken() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        
        vm.expectRevert("Invalid token");
        vm.prank(owner);
        stateOracles.addOracle(
            address(0),
            oracle,
            1e18,
            8
        );
    }
    
    function test_AddOracleInvalidWeight() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        
        vm.expectRevert("Invalid weight");
        vm.prank(owner);
        stateOracles.addOracle(
            token,
            oracle,
            0, // invalid weight
            8
        );
    }
    
    function test_AddOracleMaxOracles() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        
        // Add max oracles
        for (uint256 i = 1; i <= 5; i++) {
            address newOracle = address(uint160(0x2000 + i));
            vm.prank(owner);
            stateOracles.authorizeOracle(newOracle);
            vm.prank(owner);
            stateOracles.addOracle(token, newOracle, 1e18, 8);
        }
        
        // Try to add one more
        address extraOracle = address(0x3000);
        vm.prank(owner);
        stateOracles.authorizeOracle(extraOracle);
        vm.expectRevert("Max oracles reached");
        vm.prank(owner);
        stateOracles.addOracle(token, extraOracle, 1e18, 8);
    }
    
    function test_RemoveOracle() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        vm.prank(owner);
        stateOracles.addOracle(token, oracle, 1e18, 8);
        
        vm.prank(owner);
        stateOracles.removeOracle(token, 0);
        
        StateOracles.OracleConfig[] memory oracles = stateOracles.getTokenOracles(token);
        assertEq(oracles.length, 0);
    }
    
    function test_UpdateOracleWeight() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        vm.prank(owner);
        stateOracles.addOracle(token, oracle, 1e18, 8);
        
        vm.prank(owner);
        stateOracles.updateOracleWeight(token, 0, 2e18);
        
        StateOracles.OracleConfig[] memory oracles = stateOracles.getTokenOracles(token);
        assertEq(oracles[0].weight, 2e18);
    }
    
    function test_ToggleOracleActive() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        vm.prank(owner);
        stateOracles.addOracle(token, oracle, 1e18, 8);
        
        // Initially active
        StateOracles.OracleConfig[] memory oracles = stateOracles.getTokenOracles(token);
        assertTrue(oracles[0].isActive);
        
        // Toggle to inactive
        vm.prank(owner);
        stateOracles.toggleOracleActive(token, 0);
        oracles = stateOracles.getTokenOracles(token);
        assertFalse(oracles[0].isActive);
        
        // Toggle back to active
        stateOracles.toggleOracleActive(token, 0);
        oracles = stateOracles.getTokenOracles(token);
        assertTrue(oracles[0].isActive);
    }
    
    function test_AuthorizeOracle() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        assertTrue(stateOracles.authorizedOracles(oracle));
    }
    
    function test_DeauthorizeOracle() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        assertTrue(stateOracles.authorizedOracles(oracle));
        
        stateOracles.deauthorizeOracle(oracle);
        assertFalse(stateOracles.authorizedOracles(oracle));
    }
    
    function test_UpdatePrice() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        vm.prank(owner);
        stateOracles.addOracle(token, oracle, 1e18, 8);
        
        stateOracles.updatePrice(token);
        // Should not revert
    }
    
    function test_UpdateLiquidity() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        vm.prank(owner);
        stateOracles.addOracle(token, oracle, 1e18, 8);
        
        stateOracles.updateLiquidity(
            token,
            1000000e18, // totalLiquidity
            500000e18,  // token0Reserves
            500000e18   // token1Reserves
        );
        // Should not revert
    }
    
    function test_GetPrice() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        vm.prank(owner);
        stateOracles.addOracle(token, oracle, 1e18, 8);
        
        // Update price first
        stateOracles.updatePrice(token);
        
        (uint256 price, uint256 confidence, uint256 timestamp) = stateOracles.getPrice(token);
        assertTrue(price > 0);
        assertTrue(confidence > 0);
        assertTrue(timestamp > 0);
    }
    
    function test_GetLiquidity() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        vm.prank(owner);
        stateOracles.addOracle(token, oracle, 1e18, 8);
        
        // Update liquidity first
        stateOracles.updateLiquidity(
            token,
            1000000e18,
            500000e18,
            500000e18
        );
        
        (
            uint256 totalLiquidity,
            uint256 token0Reserves,
            uint256 token1Reserves,
            uint256 timestamp
        ) = stateOracles.getLiquidity(token);
        
        assertEq(totalLiquidity, 1000000e18);
        assertEq(token0Reserves, 500000e18);
        assertEq(token1Reserves, 500000e18);
        assertTrue(timestamp > 0);
    }
    
    function test_GetSupportedTokens() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        vm.prank(owner);
        stateOracles.addOracle(token, oracle, 1e18, 8);
        
        address[] memory tokens = stateOracles.getSupportedTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], token);
    }
    
    function test_IsPriceFresh() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        vm.prank(owner);
        stateOracles.addOracle(token, oracle, 1e18, 8);
        
        // Update price
        stateOracles.updatePrice(token);
        
        bool isFresh = stateOracles.isPriceFresh(token);
        assertTrue(isFresh);
    }
    
    function test_Pause() public {
        vm.prank(owner);
        stateOracles.pause();
        // Should not revert
    }
    
    function test_Unpause() public {
        vm.prank(owner);
        stateOracles.pause();
        stateOracles.unpause();
        // Should not revert
    }
    
    function test_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
    }
    
    function test_InvalidOracleIndex() public {
        vm.prank(owner);
        stateOracles.authorizeOracle(oracle);
        vm.prank(owner);
        stateOracles.addOracle(token, oracle, 1e18, 8);
        
        vm.expectRevert("Invalid oracle index");
        vm.prank(owner);
        stateOracles.removeOracle(token, 1);
    }
    
    function test_UnsupportedToken() public {
        vm.expectRevert("Token not supported");
        stateOracles.updatePrice(token);
    }
}

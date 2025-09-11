// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// Simple price feed interface (replaces Chainlink)
interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

/**
 * @title StateOracles
 * @notice External price feeds and state oracles for cross-chain data
 * @dev Provides price feeds, liquidity data, and market state information
 */
contract StateOracles is Ownable, Pausable, ReentrancyGuard {
    /// @notice Precision for calculations (18 decimals)
    uint256 public constant PRECISION = 1e18;
    
    /// @notice Maximum number of oracles per token
    uint256 public constant MAX_ORACLES_PER_TOKEN = 5;
    
    /// @notice Maximum price deviation between oracles (10%)
    uint256 public constant MAX_PRICE_DEVIATION = 10e16; // 10%
    
    /// @notice Maximum age for price data (1 hour)
    uint256 public constant MAX_PRICE_AGE = 3600; // 1 hour in seconds

    /**
     * @notice Oracle configuration
     * @param oracleAddress Oracle contract address
     * @param isActive Whether the oracle is active
     * @param weight Weight for weighted average calculation
     * @param lastUpdateTime Last update timestamp
     * @param decimals Number of decimals for the price
     */
    struct OracleConfig {
        address oracleAddress;
        bool isActive;
        uint256 weight;
        uint256 lastUpdateTime;
        uint8 decimals;
    }

    /**
     * @notice Price data structure
     * @param price Current price
     * @param timestamp Price timestamp
     * @param confidence Confidence level (0-100%)
     * @param source Source oracle address
     */
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
        address source;
    }

    /**
     * @notice Liquidity data structure
     * @param totalLiquidity Total liquidity in USD
     * @param token0Reserves Token0 reserves
     * @param token1Reserves Token1 reserves
     * @param timestamp Data timestamp
     * @param source Source oracle address
     */
    struct LiquidityData {
        uint256 totalLiquidity;
        uint256 token0Reserves;
        uint256 token1Reserves;
        uint256 timestamp;
        address source;
    }

    /// @notice Mapping of token to oracle configurations
    mapping(address => OracleConfig[]) public tokenOracles;
    
    /// @notice Mapping of token to current price data
    mapping(address => PriceData) public currentPrices;
    
    /// @notice Mapping of token to current liquidity data
    mapping(address => LiquidityData) public currentLiquidity;
    
    /// @notice Mapping of oracle to authorization status
    mapping(address => bool) public authorizedOracles;
    
    /// @notice Array of all supported tokens
    address[] public supportedTokens;
    
    /// @notice Mapping of token to supported status
    mapping(address => bool) public isTokenSupported;

    /**
     * @notice Constructor
     */
    constructor() Ownable(msg.sender) {
        // Initialize with default values
    }

    /**
     * @notice Add oracle for a token
     * @param token Token address
     * @param oracleAddress Oracle contract address
     * @param weight Weight for weighted average calculation
     * @param decimals Number of decimals for the price
     */
    function addOracle(
        address token,
        address oracleAddress,
        uint256 weight,
        uint8 decimals
    ) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(oracleAddress != address(0), "Invalid oracle");
        require(weight > 0, "Invalid weight");
        require(authorizedOracles[oracleAddress], "Oracle not authorized");
        
        // Check if token already has max oracles
        require(tokenOracles[token].length < MAX_ORACLES_PER_TOKEN, "Max oracles reached");
        
        // Check if oracle already exists for this token
        for (uint256 i = 0; i < tokenOracles[token].length; i++) {
            require(tokenOracles[token][i].oracleAddress != oracleAddress, "Oracle already exists");
        }
        
        tokenOracles[token].push(OracleConfig({
            oracleAddress: oracleAddress,
            isActive: true,
            weight: weight,
            lastUpdateTime: 0,
            decimals: decimals
        }));
        
        // Add token to supported list if not already there
        if (!isTokenSupported[token]) {
            supportedTokens.push(token);
            isTokenSupported[token] = true;
        }
        
        emit OracleAdded(token, oracleAddress, weight);
    }

    /**
     * @notice Remove oracle for a token
     * @param token Token address
     * @param oracleIndex Index of oracle to remove
     */
    function removeOracle(address token, uint256 oracleIndex) external onlyOwner {
        require(isTokenSupported[token], "Token not supported");
        require(oracleIndex < tokenOracles[token].length, "Invalid oracle index");
        
        address oracleAddress = tokenOracles[token][oracleIndex].oracleAddress;
        
        // Remove oracle by swapping with last element
        tokenOracles[token][oracleIndex] = tokenOracles[token][tokenOracles[token].length - 1];
        tokenOracles[token].pop();
        
        emit OracleRemoved(token, oracleAddress);
    }

    /**
     * @notice Update oracle weight
     * @param token Token address
     * @param oracleIndex Index of oracle to update
     * @param newWeight New weight
     */
    function updateOracleWeight(
        address token,
        uint256 oracleIndex,
        uint256 newWeight
    ) external onlyOwner {
        require(isTokenSupported[token], "Token not supported");
        require(oracleIndex < tokenOracles[token].length, "Invalid oracle index");
        require(newWeight > 0, "Invalid weight");
        
        tokenOracles[token][oracleIndex].weight = newWeight;
        
        emit OracleWeightUpdated(token, oracleIndex, newWeight);
    }

    /**
     * @notice Toggle oracle active status
     * @param token Token address
     * @param oracleIndex Index of oracle to toggle
     */
    function toggleOracleActive(
        address token,
        uint256 oracleIndex
    ) external onlyOwner {
        require(isTokenSupported[token], "Token not supported");
        require(oracleIndex < tokenOracles[token].length, "Invalid oracle index");
        
        tokenOracles[token][oracleIndex].isActive = !tokenOracles[token][oracleIndex].isActive;
        
        emit OracleToggled(token, oracleIndex, tokenOracles[token][oracleIndex].isActive);
    }

    /**
     * @notice Authorize an oracle
     * @param oracleAddress Oracle contract address
     */
    function authorizeOracle(address oracleAddress) external onlyOwner {
        require(oracleAddress != address(0), "Invalid oracle");
        require(!authorizedOracles[oracleAddress], "Oracle already authorized");
        
        authorizedOracles[oracleAddress] = true;
        
        emit OracleAuthorized(oracleAddress);
    }

    /**
     * @notice Deauthorize an oracle
     * @param oracleAddress Oracle contract address
     */
    function deauthorizeOracle(address oracleAddress) external onlyOwner {
        require(authorizedOracles[oracleAddress], "Oracle not authorized");
        
        authorizedOracles[oracleAddress] = false;
        
        emit OracleDeauthorized(oracleAddress);
    }

    /**
     * @notice Update price data for a token
     * @param token Token address
     */
    function updatePrice(address token) external nonReentrant {
        require(isTokenSupported[token], "Token not supported");
        require(tokenOracles[token].length > 0, "No oracles for token");
        
        (uint256 price, uint256 confidence) = _getAggregatedPrice(token);
        
        currentPrices[token] = PriceData({
            price: price,
            timestamp: block.timestamp,
            confidence: confidence,
            source: address(this)
        });
        
        emit PriceUpdated(token, price, confidence);
    }

    /**
     * @notice Update liquidity data for a token
     * @param token Token address
     * @param totalLiquidity Total liquidity in USD
     * @param token0Reserves Token0 reserves
     * @param token1Reserves Token1 reserves
     */
    function updateLiquidity(
        address token,
        uint256 totalLiquidity,
        uint256 token0Reserves,
        uint256 token1Reserves
    ) external onlyOwner {
        require(isTokenSupported[token], "Token not supported");
        
        currentLiquidity[token] = LiquidityData({
            totalLiquidity: totalLiquidity,
            token0Reserves: token0Reserves,
            token1Reserves: token1Reserves,
            timestamp: block.timestamp,
            source: msg.sender
        });
        
        emit LiquidityUpdated(token, totalLiquidity, token0Reserves, token1Reserves);
    }

    /**
     * @notice Get current price for a token
     * @param token Token address
     * @return price Current price
     * @return confidence Confidence level
     * @return timestamp Price timestamp
     */
    function getPrice(address token) external view returns (
        uint256 price,
        uint256 confidence,
        uint256 timestamp
    ) {
        require(isTokenSupported[token], "Token not supported");
        
        PriceData memory priceData = currentPrices[token];
        require(priceData.price > 0, "No price data");
        require(block.timestamp - priceData.timestamp <= MAX_PRICE_AGE, "Price data too old");
        
        return (priceData.price, priceData.confidence, priceData.timestamp);
    }

    /**
     * @notice Get current liquidity for a token
     * @param token Token address
     * @return totalLiquidity Total liquidity in USD
     * @return token0Reserves Token0 reserves
     * @return token1Reserves Token1 reserves
     * @return timestamp Liquidity timestamp
     */
    function getLiquidity(address token) external view returns (
        uint256 totalLiquidity,
        uint256 token0Reserves,
        uint256 token1Reserves,
        uint256 timestamp
    ) {
        require(isTokenSupported[token], "Token not supported");
        
        LiquidityData memory liquidityData = currentLiquidity[token];
        require(liquidityData.totalLiquidity > 0, "No liquidity data");
        
        return (
            liquidityData.totalLiquidity,
            liquidityData.token0Reserves,
            liquidityData.token1Reserves,
            liquidityData.timestamp
        );
    }

    /**
     * @notice Get all supported tokens
     * @return tokens Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory tokens) {
        return supportedTokens;
    }

    /**
     * @notice Get oracles for a token
     * @param token Token address
     * @return oracles Array of oracle configurations
     */
    function getTokenOracles(address token) external view returns (OracleConfig[] memory oracles) {
        return tokenOracles[token];
    }

    /**
     * @notice Check if price data is fresh
     * @param token Token address
     * @return isFresh True if price data is fresh
     */
    function isPriceFresh(address token) external view returns (bool isFresh) {
        if (!isTokenSupported[token]) return false;
        
        PriceData memory priceData = currentPrices[token];
        return priceData.price > 0 && block.timestamp - priceData.timestamp <= MAX_PRICE_AGE;
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

    // ============ Internal Functions ============

    /**
     * @notice Get aggregated price from all active oracles
     * @param token Token address
     * @return price Aggregated price
     * @return confidence Confidence level
     */
    function _getAggregatedPrice(address token) internal view returns (uint256 price, uint256 confidence) {
        OracleConfig[] memory oracles = tokenOracles[token];
        require(oracles.length > 0, "No oracles available");
        
        uint256 totalWeight = 0;
        uint256 weightedPriceSum = 0;
        uint256 validOracles = 0;
        uint256[] memory prices = new uint256[](oracles.length);
        
        // Collect prices from all active oracles
        for (uint256 i = 0; i < oracles.length; i++) {
            if (oracles[i].isActive) {
                try this._getOraclePrice(oracles[i].oracleAddress, oracles[i].decimals) returns (uint256 oraclePrice) {
                    if (oraclePrice > 0) {
                        prices[validOracles] = oraclePrice;
                        weightedPriceSum += oraclePrice * oracles[i].weight;
                        totalWeight += oracles[i].weight;
                        validOracles++;
                    }
                } catch {
                    // Skip failed oracles
                    continue;
                }
            }
        }
        
        require(validOracles > 0, "No valid oracles");
        
        // Calculate weighted average price
        price = totalWeight > 0 ? weightedPriceSum / totalWeight : 0;
        
        // Calculate confidence based on price consistency
        confidence = _calculatePriceConfidence(prices, validOracles, price);
        
        return (price, confidence);
    }

    /**
     * @notice Get price from a specific oracle
     * @param oracleAddress Oracle contract address
     * @param decimals Number of decimals
     * @return price Price from oracle
     */
    function _getOraclePrice(address oracleAddress, uint8 decimals) external view returns (uint256 price) {
        try AggregatorV3Interface(oracleAddress).latestRoundData() returns (
            uint80,
            int256 answer,
            uint256,
            uint256,
            uint80
        ) {
            if (answer > 0) {
                // Convert to 18 decimals
                if (decimals < 18) {
                    price = uint256(answer) * (10 ** (18 - decimals));
                } else if (decimals > 18) {
                    price = uint256(answer) / (10 ** (decimals - 18));
                } else {
                    price = uint256(answer);
                }
            }
        } catch {
            price = 0;
        }
    }

    /**
     * @notice Calculate price confidence based on consistency
     * @param prices Array of prices
     * @param count Number of valid prices
     * @param averagePrice Average price
     * @return confidence Confidence level
     */
    function _calculatePriceConfidence(
        uint256[] memory prices,
        uint256 count,
        uint256 averagePrice
    ) internal pure returns (uint256 confidence) {
        if (count == 0 || averagePrice == 0) return 0;
        
        uint256 totalDeviation = 0;
        
        for (uint256 i = 0; i < count; i++) {
            uint256 deviation = prices[i] > averagePrice ? 
                prices[i] - averagePrice : averagePrice - prices[i];
            totalDeviation += deviation;
        }
        
        uint256 averageDeviation = totalDeviation / count;
        uint256 deviationPercent = (averageDeviation * PRECISION) / averagePrice;
        
        // Confidence decreases with deviation
        if (deviationPercent <= 1e16) { // 1% deviation
            confidence = 95e16; // 95%
        } else if (deviationPercent <= 5e16) { // 5% deviation
            confidence = 80e16; // 80%
        } else if (deviationPercent <= 10e16) { // 10% deviation
            confidence = 60e16; // 60%
        } else {
            confidence = 30e16; // 30%
        }
    }

    // ============ Events ============

    event OracleAdded(address indexed token, address indexed oracle, uint256 weight);
    event OracleRemoved(address indexed token, address indexed oracle);
    event OracleWeightUpdated(address indexed token, uint256 oracleIndex, uint256 newWeight);
    event OracleToggled(address indexed token, uint256 oracleIndex, bool isActive);
    event OracleAuthorized(address indexed oracle);
    event OracleDeauthorized(address indexed oracle);
    event PriceUpdated(address indexed token, uint256 price, uint256 confidence);
    event LiquidityUpdated(address indexed token, uint256 totalLiquidity, uint256 token0Reserves, uint256 token1Reserves);
}

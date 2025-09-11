// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);
    function getRoundData(uint80 _roundId) external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

contract MockOracle is AggregatorV3Interface {
    uint8 public constant decimals = 8;
    string public constant description = "Mock Oracle";
    uint256 public constant version = 1;
    
    uint80 public roundId = 1;
    int256 public answer = 2000e8; // $2000 with 8 decimals
    uint256 public startedAt = block.timestamp;
    uint256 public updatedAt = block.timestamp;
    uint80 public answeredInRound = 1;
    
    function latestRoundData() external view override returns (
        uint80,
        int256,
        uint256,
        uint256,
        uint80
    ) {
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
    
    function getRoundData(uint80 _roundId) external view override returns (
        uint80,
        int256,
        uint256,
        uint256,
        uint80
    ) {
        return (_roundId, answer, startedAt, updatedAt, answeredInRound);
    }
    
    function setPrice(int256 _price) external {
        answer = _price;
        updatedAt = block.timestamp;
        roundId++;
        answeredInRound = roundId;
    }
}

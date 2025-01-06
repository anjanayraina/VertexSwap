// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Interfaces/AggregatorV3Interface.sol";

contract OracleManager {
    struct OracleInfo {
        AggregatorV3Interface priceOracle;
        bool exists;
    }

    mapping(address => OracleInfo) private oracles;

    event OracleAdded(address indexed token, address oracle);
    event OracleRemoved(address indexed token);

    // Add a price oracle for a token
    function addOracle(address token, address oracle) external {
        require(token != address(0), "Invalid token address");
        require(oracle != address(0), "Invalid oracle address");
        require(!oracles[token].exists, "Oracle already exists for this token");

        oracles[token] = OracleInfo({
            priceOracle: AggregatorV3Interface(oracle),
            exists: true
        });

        emit OracleAdded(token, oracle);
    }

    // Remove a price oracle for a token
    function removeOracle(address token) external {
        require(oracles[token].exists, "No oracle exists for this token");

        delete oracles[token];

        emit OracleRemoved(token);
    }

    // Get the latest price of a token
    function getPrice(address token) external view returns (uint256) {
        require(oracles[token].exists, "No oracle exists for this token");

        (, int256 price, , , ) = oracles[token].priceOracle.latestRoundData();
        require(price > 0, "Invalid price from oracle");

        return uint256(price);
    }
}

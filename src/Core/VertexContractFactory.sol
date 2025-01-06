// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./VertexPool.sol";

contract VertexContractFactory {
    // Mapping from token pair to pool address
    mapping(address => mapping(address => address)) public getPool;
    // Array of all pools
    address[] public allPools;

    event PoolCreated(address indexed token0, address indexed token1, address pool, uint256);

    // Function to create a new pool
    function createPool(address tokenA, address tokenB) external returns (address pool) {
        require(tokenA != tokenB, "Factory: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "Factory: ZERO_ADDRESS");
        require(getPool[token0][token1] == address(0), "Factory: POOL_EXISTS");

        bytes memory bytecode = type(VertexPool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        // Initialize the pool with token addresses and the caller as the owner
        // VertexPool(pool).initialize(token0, token1, msg.sender);

        getPool[token0][token1] = pool;
        getPool[token1][token0] = pool; 
        allPools.push(pool);
        emit PoolCreated(token0, token1, pool, allPools.length);
    }

    // Function to get the number of pools
    function allPoolsLength() external view returns (uint256) {
        return allPools.length;
    }
}

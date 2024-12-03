// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract AMM is ERC20 {
    using SafeERC20 for IERC20;

    // Tokens involved in the pool
    IERC20 public token0;
    IERC20 public token1;

    // Reserves of each token, stored as uint112 to save gas
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    // Constants
    uint256 private constant MINIMUM_LIQUIDITY = 10**3;
    uint256 private constant FEE_RATE = 3; // Represents 0.30%

    // Events
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    // Constructor to initialize the contract with token addresses
    constructor(address _token0, address _token1) ERC20("Vertex Swap Token" , "VST"){
        require(_token0 != _token1, "Tokens must be different");
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    // Get current reserves
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    // Internal function to update reserves
    function _update(uint256 balance0, uint256 balance1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "Overflow");
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp % 2**32);
        emit Sync(reserve0, reserve1);
    }

    // Add liquidity to the pool
    function mint(address to) external returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            // Permanently lock the first MINIMUM_LIQUIDITY tokens
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }

        require(liquidity > 0, "Insufficient liquidity minted");
        _mint(to, liquidity);

        _update(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1);
    }

    // Remove liquidity from the pool
    function burn(address to) external returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        IERC20 _token0 = token0;
        IERC20 _token1 = token1;

        uint256 balance0 = _token0.balanceOf(address(this));
        uint256 balance1 = _token1.balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));

        uint256 _totalSupply = totalSupply();
        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;

        require(amount0 > 0 && amount1 > 0, "Insufficient liquidity burned");
        _burn(address(this), liquidity);
        _token0.safeTransfer(to, amount0);
        _token1.safeTransfer(to, amount1);

        balance0 = _token0.balanceOf(address(this));
        balance1 = _token1.balanceOf(address(this));

        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // Swap tokens
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external {
        require(amount0Out > 0 || amount1Out > 0, "Insufficient output amount");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "Insufficient liquidity");

        uint256 balance0;
        uint256 balance1;
        {
            IERC20 _token0 = token0;
            IERC20 _token1 = token1;
            require(to != address(_token0) && to != address(_token1), "Invalid to address");

            if (amount0Out > 0) _token0.safeTransfer(to, amount0Out);
            if (amount1Out > 0) _token1.safeTransfer(to, amount1Out);

            balance0 = _token0.balanceOf(address(this));
            balance1 = _token1.balanceOf(address(this));
        }

        uint256 amount0In = balance0 > (_reserve0 - amount0Out) ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > (_reserve1 - amount1Out) ? balance1 - (_reserve1 - amount1Out) : 0;

        require(amount0In > 0 || amount1In > 0, "Insufficient input amount");

        // Adjusted balances after fee
        uint256 balance0Adjusted = (balance0 * 1000) - (amount0In * FEE_RATE);
        uint256 balance1Adjusted = (balance1 * 1000) - (amount1In * FEE_RATE);

        require(
            balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * uint256(_reserve1) * (1000**2),
            "K"
        );

        _update(balance0, balance1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // Helper functions
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x <= y ? x : y;
    }
}
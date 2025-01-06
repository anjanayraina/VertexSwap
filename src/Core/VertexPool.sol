// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./VertexFeeVault.sol";

contract VertexPool is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public token0;
    IERC20 public token1;
    uint112 private reserve0;
    uint112 private reserve1;

    VertexFeeVault public feeVault;
    uint256 private constant FEE_RATE = 3; // 0.30% fee

    constructor(address _token0, address _token1) ERC20("Liquidity Pool Token", "LPT") {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        feeVault = new VertexFeeVault(address(this));
    }

    function mint(address to) external returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1) = getReserves();
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = sqrt(amount0 * amount1);
        } else {
            liquidity = min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }

        require(liquidity > 0, "Pool: INSUFFICIENT_LIQUIDITY");
        _mint(to, liquidity);
        _update(balance0, balance1);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to) external {
        require(amount0Out > 0 || amount1Out > 0, "Pool: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "Pool: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;

        if (amount0Out > 0) token0.safeTransfer(to, amount0Out);
        if (amount1Out > 0) token1.safeTransfer(to, amount1Out);

        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));

        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;

        require(amount0In > 0 || amount1In > 0, "Pool: INSUFFICIENT_INPUT_AMOUNT");

        uint256 fee0 = (amount0In * FEE_RATE) / 1000;
        uint256 fee1 = (amount1In * FEE_RATE) / 1000;

        if (fee0 > 0) token0.safeTransfer(address(feeVault), fee0);
        if (fee1 > 0) token1.safeTransfer(address(feeVault), fee1);

        uint256 balance0Adjusted = balance0 - fee0;
        uint256 balance1Adjusted = balance1 - fee1;

        require(
            balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * uint256(_reserve1),
            "Pool: K"
        );

        _update(balance0, balance1);
    }

    function getReserves() public view returns (uint112, uint112) {
        return (reserve0, reserve1);
    }

    function _update(uint256 balance0, uint256 balance1) private {
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
    }

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

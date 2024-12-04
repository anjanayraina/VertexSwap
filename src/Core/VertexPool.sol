// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./VertexFeeVault.sol";

contract VertexPool is ERC20 {
    using SafeERC20 for IERC20;

    // Tokens in the pool
    IERC20 public token0;
    IERC20 public token1;

    // Reserves of each token
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    // Fee vault contract
    VertexFeeVault public feeVault;

    // Constants
    uint256 private constant MINIMUM_LIQUIDITY = 10**3;
    uint256 private constant FEE_RATE = 3; // 0.30% fee

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

    // Constructor
    constructor() ERC20("Liquidity Pool Token", "LPT") {}

    // Initialize the pool with token addresses
    function initialize(address _token0, address _token1, address owner) external {
        require(address(token0) == address(0) && address(token1) == address(0), "Pool: ALREADY_INITIALIZED");
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);

        // Deploy the fee vault with the pool as the asset and the owner as the fee vault owner
        feeVault = new VertexFeeVault(IERC20(address(this)), owner);
    }

    // Remaining methods (mint, burn, swap, etc.) are unchanged...
}

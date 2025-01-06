// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../Interfaces/AggregatorV3Interface.sol";

contract MultiTokenVault is ERC20, Ownable {
    uint256 private constant PRECISON_FACTOR = 3; 
    using SafeERC20 for IERC20;

    struct TokenInfo {
        bool supported;
        AggregatorV3Interface priceOracle;
    }

    mapping(address => TokenInfo) public tokens; // Supported tokens and their oracles
    address[] public tokenList; // List of supported tokens

    constructor(string memory name, string memory symbol, address owner  ) ERC20(name, symbol) Ownable(owner){

    }

    // Add a token to the supported list
    function addToken(address token, address oracle) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(oracle != address(0), "Invalid oracle address");
        require(!tokens[token].supported, "Token already supported");

        tokens[token] = TokenInfo({
            supported: true,
            priceOracle: AggregatorV3Interface(oracle)
        });
        tokenList.push(token);
    }

    // Remove a token from the supported list
    function removeToken(address token) external onlyOwner {
        require(tokens[token].supported, "Token not supported");
        tokens[token].supported = false;

        for (uint256 i = 0; i < tokenList.length; i++) {
            if (tokenList[i] == token) {
                tokenList[i] = tokenList[tokenList.length - 1];
                tokenList.pop();
                break;
            }
        }
    }

// Calculate total vault value in USD
// Calculate total assets in USD with 3-decimal precision
function totalAssets() public view returns (uint256 totalValue) {
    uint256 precisionFactor = 10**PRECISON_FACTOR; // For 3-decimal precision
    for (uint256 i = 0; i < tokenList.length; i++) {
        address token = tokenList[i];
        if (tokens[token].supported) {
            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 price = getTokenPrice(token); 
            uint256 decimals = IERC20Metadata(token).decimals();
            totalValue += (balance * price * precisionFactor) / (10**(decimals + tokens[token].priceOracle.decimals()));
        }
    }
}


    // Get token price from oracle
    function getTokenPrice(address token) public view returns (uint256) {
        require(tokens[token].supported, "Token not supported");
        (, int256 price, , ,) = tokens[token].priceOracle.latestRoundData();
        require(price > 0, "Invalid price from oracle");
        return uint256(price);
    }

    // Deposit tokens into the vault and mint shares
    function deposit(address token, uint256 amount, address receiver) external returns (uint256 shares) {
        require(tokens[token].supported, "Token not supported");
        require(amount > 0, "Cannot deposit zero assets");

        uint256 vaultValueBefore = totalAssets();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 vaultValueAfter = totalAssets();
        uint256 depositedValue = vaultValueAfter - vaultValueBefore;

        shares = (depositedValue * totalSupply()) / vaultValueBefore;
        _mint(receiver, shares);
    }

    // Withdraw tokens from the vault and burn shares
    function withdraw(uint256 shares, address receiver) external returns (uint256 assets) {
        require(shares > 0, "Cannot withdraw zero shares");
        uint256 totalValue = totalAssets();
        uint256 shareValue = (shares * totalValue) / totalSupply();
        _burn(msg.sender, shares);

        uint256 remainingValue = shareValue;

        for (uint256 i = 0; i < tokenList.length && remainingValue > 0; i++) {
            address token = tokenList[i];
            if (!tokens[token].supported) continue;

            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 price = getTokenPrice(token);
            uint256 decimals = IERC20Metadata(token).decimals();
            uint256 tokenValue = (balance * price) / (10**decimals);

            uint256 amountToTransfer = 0;
            if (remainingValue <= tokenValue) {
                amountToTransfer = (remainingValue * (10**decimals)) / price;
                remainingValue = 0;
            } else {
                amountToTransfer = balance;
                remainingValue -= tokenValue;
            }

            if (amountToTransfer > 0) {
                IERC20(token).safeTransfer(receiver, amountToTransfer);
            }
        }

        assets = shareValue; // Total USD value of withdrawn tokens
    }
}

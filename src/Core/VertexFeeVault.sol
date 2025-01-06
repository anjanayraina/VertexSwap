// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Interfaces/AggregatorV3Interface.sol";

contract VertexFeeVault is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    // Supported tokens and their Chainlink price oracles
    struct TokenInfo {
        bool supported;
        AggregatorV3Interface priceOracle;
    }

    mapping(address => TokenInfo) public tokens;
    address[] public tokenList;

    // Constructor
    constructor(IERC20 asset, address initialOwner)
        ERC4626(asset)
        ERC20("Vertex Fee Vault Token", "VFVT")
        Ownable(initialOwner)
    {}

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

        // Remove from tokenList
        for (uint256 i = 0; i < tokenList.length; i++) {
            if (tokenList[i] == token) {
                tokenList[i] = tokenList[tokenList.length - 1];
                tokenList.pop();
                break;
            }
        }
    }

    // Calculate total assets in USD
    function totalAssetsInUSD() public view returns (uint256 totalValue) {
        for (uint256 i = 0; i < tokenList.length; i++) {
            address token = tokenList[i];
            if (tokens[token].supported) {
                uint256 balance = IERC20(token).balanceOf(address(this));
                uint256 price = getTokenPrice(token); // @audit the oracles will probably send the data in terms of deciamls so keep that in mind 
                totalValue += (balance * price) / (10**ERC20(token).decimals());
            }
        }
    }

    // Get the price of a token in USD using Chainlink
    function getTokenPrice(address token) public view returns (uint256) {
        require(tokens[token].supported, "Token not supported");
        (, int256 price, , ,) = tokens[token].priceOracle.latestRoundData();
        require(price > 0, "Invalid price from oracle");
        return uint256(price);
    }

    // Override deposit function to mint shares
    function deposit(address token , uint256 amount, address receiver) public  returns (uint256 shares) {
        require(amount> 0, "Cannot deposit zero assets");
        require(tokens[token].supported, "Token not supported");

        uint256 vaultValueBefore = totalAssetsInUSD();
        IERC20(token).safeTransferFrom(_msgSender(), address(this), amount );

        uint256 vaultValueAfter = totalAssetsInUSD();
        uint256 assetUSDValue = vaultValueAfter - vaultValueBefore;

        shares = (assetUSDValue * totalSupply()) / vaultValueBefore;
        _mint(receiver, shares);

        return shares;
    }

    // Override withdraw function to burn shares
    function withdraw(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        require(shares > 0, "Cannot withdraw zero shares");

        uint256 totalValue = totalAssetsInUSD();
        uint256 shareValue = (shares * totalValue) / totalSupply();

        _burn(owner, shares);

        uint256 remainingValue = shareValue;

        for (uint256 i = 0; i < tokenList.length && remainingValue > 0; i++) {
            address token = tokenList[i];
            if (!tokens[token].supported) continue;

            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 price = getTokenPrice(token);
            uint256 tokenValue = (balance * price) / (10**ERC20(token).decimals());

            uint256 amountToTransfer = 0;
            if (remainingValue <= tokenValue) {
                amountToTransfer = (remainingValue * (10**ERC20(token).decimals())) / price;
                remainingValue = 0;
            } else {
                amountToTransfer = balance;
                remainingValue -= tokenValue;
            }

            if (amountToTransfer > 0) {
                IERC20(token).safeTransfer(receiver, amountToTransfer);
            }
        }

        assets = shareValue;
        return assets;
    }
}

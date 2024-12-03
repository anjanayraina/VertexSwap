// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract FeeVault is ERC4626 {
  constructor(address asset_) ERC4626(IERC20Metadata(asset_)) ERC20("Fee Vault Token", "FVT") {
        // FeeVault is initialized with the underlying asset and metadata
    }



    // Additional functions can be added as needed
}

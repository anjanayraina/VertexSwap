// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VertexToken is ERC20 {
    constructor(uint256 amount) ERC20("Vertex Governance Token", "VERT") {
        _mint(msg.sender, amount); 
    }
}

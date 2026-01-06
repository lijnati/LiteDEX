// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SimpleDEX.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

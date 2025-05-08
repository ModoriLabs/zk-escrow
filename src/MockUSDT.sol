// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {
        // Initial supply of 100,000 USDT with 6 decimals
        _mint(msg.sender, 100000 * 10 ** 6);
    }

    // Override decimals to return 6 instead of the default 18
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // Custom mint function for testing
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

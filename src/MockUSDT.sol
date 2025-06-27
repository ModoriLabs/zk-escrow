// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockUSDT is ERC20, Ownable {
    constructor(address _owner) ERC20("Mock USDT", "USDT") Ownable(_owner) {
        // Initial supply of 100,000 USDT with 6 decimals
        _mint(_owner, 100_000 * 10 ** 6);
    }

    // Override decimals to return 6 instead of the default 18
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // Custom mint function for testing
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

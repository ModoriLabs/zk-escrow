// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract KRW is ERC20, Ownable {
    constructor(address _owner) ERC20("Korea Won", "KRW") Ownable(_owner) {
    }

    // Custom mint function for testing
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

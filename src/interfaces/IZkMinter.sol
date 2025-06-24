// SPDX-License-Identifier: MIT

pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IZkMinter {
    struct Intent {
        address owner;                              // Address of the intent owner
        address to;                                 // Address to forward funds to (can be same as owner)
        uint256 amount;                             // Amount of the deposit.token the owner wants to take
        uint256 timestamp;                          // Timestamp of the intent
        address paymentVerifier;                    // Address of the payment verifier corresponding to payment service the owner is
    }

    event IntentSignaled(
        address to,
        address verifier,
        uint256 amount,
        uint256 intentId
    );

    error InvalidAmount();
}

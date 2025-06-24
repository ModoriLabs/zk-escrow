// SPDX-License-Identifier: MIT

pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEscrow {
    struct Range {
        uint256 min;
        uint256 max;
    }

    struct Deposit {
        address depositor;
        IERC20 token;
        uint256 amount;
        Range intentAmountRange;
        bool acceptingIntents;
        uint256 remainingDeposits;
        uint256 outstandingIntentAmount;
        bytes32[] intentHashes;
    }

    struct Intent {
        address owner;
        address to;
        uint256 depositId;
        uint256 amount;
        uint256 timestamp;
        address paymentVerifier;
        bytes32 fiatCurrency;
        uint256 conversionRate;
    }
}

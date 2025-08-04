// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEscrow {
    struct Range {
        uint256 min;                                // Minimum value of the range
        uint256 max;                                // Maximum value of the range
    }

    struct Deposit {
        address depositor;                          // Address of depositor
        IERC20 token;                               // Address of deposit token
        uint256 amount;                             // Amount of deposit token
        Range intentAmountRange;                    // Range of take amount per intent
        // Deposit state
        bool acceptingIntents;                      // State: True if the deposit is accepting intents, False otherwise
        uint256 remainingDeposits;                  // State: Amount of remaining deposited liquidity
        uint256 outstandingIntentAmount;            // State: Amount of outstanding intents (may include expired intents)
        uint256[] intentIds;                        // State: Array of ids of all open intents (may include some expired if not pruned)
    }

    struct Currency {
        bytes32 code;                               // Currency code (keccak256 hash of the currency code)
        uint256 conversionRate;                     // Conversion rate of deposit token to fiat currency
    }

    struct DepositVerifierData {
        string payeeDetails;                        // Payee details, could be both hash or raw details; verifier will decide how to parse it
        bytes data;                                 // Verification Data: Additional data used for payment verification; Can hold attester address
        // in case of TLS proofs, domain key hash in case of zkEmail proofs, currency code etc.
    }

    struct Intent {
        address owner;                              // Address of the intent owner
        address to;                                 // Address to forward funds to (can be same as owner)
        uint256 depositId;                          // ID of the deposit the intent is associated with
        uint256 amount;                             // Amount of the deposit.token the owner wants to take
        uint256 timestamp;                          // Timestamp of the intent
        address paymentVerifier;                    // Address of the payment verifier corresponding to payment service the owner is
                                                    // going to pay with offchain
        bytes32 fiatCurrency;                       // Currency code that the owner is paying in offchain (keccak256 hash of the currency code)
        uint256 conversionRate;                     // Conversion rate of deposit token to fiat currency at the time of intent
    }

    struct RedeemRequest {
        address owner;
        uint256 amount;
        uint256 timestamp;
    }

    event IntentSignaled(
        address to,
        address verifier,
        uint256 amount,
        uint256 intentId
    );

    event IntentFulfilled(
        uint256 indexed intentId,
        uint256 indexed depositId,
        address indexed verifier,
        address owner,
        address to,
        uint256 amount
    );

    event IntentReleased(
        uint256 indexed intentId,
        uint256 indexed depositId,
        address owner,
        address to,
        uint256 amount
    );

    event IntentCancelled(
        uint256 intentId
    );

    event RedeemRequestSignaled(
        uint256 indexed redeemId,
        address indexed owner,
        uint256 amount,
        string accountNumber
    );

    event RedeemRequestFulfilled(
        uint256 redeemId
    );

    event RedeemRequestCancelled(
        uint256 redeemId
    );

    event DepositCreated(
        uint256 depositId,
        address depositor,
        IERC20 token,
        uint256 amount,
        Range intentAmountRange
    );

    event DepositVerifierAdded(
        uint256 indexed depositId,
        address indexed verifier,
        bytes32 payeeDetailsHash
    );

    event DepositCurrencyAdded(
        uint256 indexed depositId,
        address indexed verifier,
        bytes32 indexed currency,
        uint256 conversionRate
    );

    event DepositConversionRateUpdated(
        uint256 indexed depositId,
        address indexed verifier,
        bytes32 fiatCurrency,
        uint256 newConversionRate
    );

    event DepositIncreased(
        uint256 indexed depositId,
        address indexed depositor,
        uint256 additionalAmount,
        uint256 newTotalAmount
    );

    event DepositWithdrawn(
        uint256 indexed depositId,
        address indexed depositor,
        uint256 amount
    );

    event DepositClosed(uint256 depositId, address depositor);

    event DepositIntentAmountRangeUpdated(
        uint256 indexed depositId,
        Range oldRange,
        Range newRange
    );

    event PaymentVerifierAdded(address verifier);
    event PaymentVerifierRemoved(address verifier);
    event IntentExpirationPeriodSet(uint256 intentExpirationPeriod);
    event MaxIntentsPerDepositUpdated(uint256 oldMax, uint256 newMax);

    error InvalidAmount();
    error InvalidRecipient();
    error IntentAlreadyExists();
    error IntentNotFound();
    error InvalidAccountNumber();
    error RedeemRequestNotFound();
    error RedeemAlreadyExists();
    error OnlyDepositor();
    error InvalidIntentAmountRange();
    error DepositNotFound();
    error DepositNotAcceptingIntents();
}

//SPDX-License-Identifier: MIT

pragma solidity 0.8.29;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IPaymentVerifier } from "./verifiers/interfaces/IPaymentVerifier.sol";
import { IEscrow } from "./interfaces/IEscrow.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IMintableERC20 } from "./interfaces/IMintableERC20.sol";
import { StringUtils } from "./external/ReclaimStringUtils.sol";

contract Escrow is Ownable, Pausable, IEscrow {
    address public token;
    uint256 public intentCount;
    uint256 public redeemCount;

    // Mapping of address to intentHash (Only one intent per address at a given time)
    mapping(address => uint256[]) public accountDeposits;
    mapping(address => uint256) public accountIntent;

    mapping(uint256 => Deposit) public deposits;
    mapping(uint256 => Intent) public intents;
    address[] public verifiers;
    mapping(address => DepositVerifierData) public depositVerifierData;

    // Mapping of depositId to verifier address to mapping of fiat currency to conversion rate. Each payment service can support
    // multiple currencies. Depositor can specify list of currencies and conversion rates for each payment service.
    // Example: Deposit 1 => Venmo => USD: 1e18
    //                    => Revolut => USD: 1e18, EUR: 1.2e18, SGD: 1.5e18
    mapping(uint256 => mapping(address => mapping(bytes32 => uint256))) public depositCurrencyConversionRate;
    mapping(uint256 => mapping(address => bytes32[])) public depositCurrencies; // Handy mapping to get all currencies for a deposit and verifier

    mapping(address => uint256) public accountRedeemRequest;
    mapping(uint256 => RedeemRequest) public redeemRequests;

    uint256 public intentExpirationPeriod;

    uint256 public depositCounter;

    constructor(
        address _owner,
        address _token
    ) Ownable(_owner) {
        token = _token;
    }

    function signalIntent(
        address _to,
        uint256 _amount,
        address _verifier
    ) external whenNotPaused {
        require(_to != address(0), "Invalid recipient address");
        require(_amount > 0, InvalidAmount());
        require(_verifier != address(0), "Invalid verifier address");

        // Check if an intent already exists for this address
        uint256 intentId = accountIntent[msg.sender];
        require(intentId == 0, "Intent already exists for this address");

        // Create a new intent
        intentId = ++intentCount;
        intents[intentId] = Intent({
            owner: msg.sender,
            to: _to,
            amount: _amount,
            timestamp: block.timestamp,
            paymentVerifier: _verifier
        });

        accountIntent[msg.sender] = intentId;

        emit IntentSignaled(_to, _verifier, _amount, intentId);
    }

    /**
     * @notice Only callable by the originator of the intent. Allowed even when paused.
     *
     * @param _intentId    ID of intent being cancelled
     */
    function cancelIntent(uint256 _intentId) external {
        Intent memory intent = intents[_intentId];
        require(intent.owner == msg.sender, "Sender must be the intent owner");
        _pruneIntent(_intentId);
        emit IntentCancelled(_intentId);
    }

    function fulfillIntent(
        bytes calldata _paymentProof,
        uint256 _intentId
    ) external whenNotPaused {
        Intent memory intent = intents[_intentId];

        address verifier = intent.paymentVerifier;
        require(verifier != address(0), IntentNotFound());

        DepositVerifierData memory verifierData = depositVerifierData[verifier];
        (bool success, bytes32 intentHash) = IPaymentVerifier(verifier).verifyPayment(
            IPaymentVerifier.VerifyPaymentData({
                paymentProof: _paymentProof,
                mintToken: token,
                intentAmount: intent.amount,
                intentTimestamp: intent.timestamp,
                payeeDetails: verifierData.payeeDetails,
                conversionRate: 1e18, // PRECISE_UNIT is 1e18
                data: verifierData.data
            })
        );
        require(success, "Payment verification failed");
        require(keccak256(abi.encode(StringUtils.uint2str(_intentId))) == intentHash, "Intent hash mismatch");

        _pruneIntent(_intentId);

        _transferFunds(IERC20(token), intentHash, intent, verifier);

        emit IntentFulfilled(
            intentHash,
            verifier,
            intent.owner,
            intent.to,
            intent.amount
        );
    }

    function createDeposit(
        IERC20 _token,
        uint256 _amount,
        Range calldata _intentAmountRange,
        address[] calldata _verifiers,
        DepositVerifierData[] calldata _verifierData,
        Currency[][] calldata _currencies
    ) external whenNotPaused {
        _validateCreateDeposit(_amount, _intentAmountRange, _verifier);

        uint256 depositId = depositCounter++;
        accountDeposits[msg.sender].push(depositId);

        deposits[depositId] = Deposit({
            depositor: msg.sender,
            token: _token,
            amount: _amount,
            intentAmountRange: _intentAmountRange,
            acceptingIntents: true,
            intentHashes: new bytes32[](0),
            remainingDeposits: _amount,
            outstandingIntentAmount: 0
        });

        emit DepositReceived(depositId, msg.sender, _token, _amount, _intentAmountRange);

        for (uint256 i = 0; i < _verifiers.length; i++) {
            address verifier = _verifiers[i];
            require(
                bytes(depositVerifierData[depositId][verifier].payeeDetails).length == 0,
                "Verifier data already exists"
            );
            depositVerifierData[depositId][verifier] = _verifierData[i];
            depositVerifiers[depositId].push(verifier);

            bytes32 payeeDetailsHash = keccak256(abi.encodePacked(_verifierData[i].payeeDetails));
            emit DepositVerifierAdded(depositId, verifier, payeeDetailsHash, _verifierData[i].intentGatingService);

            for (uint256 j = 0; j < _currencies[i].length; j++) {
                Currency memory currency = _currencies[i][j];
                require(
                    depositCurrencyConversionRate[depositId][verifier][currency.code] == 0,
                    "Currency conversion rate already exists"
                );
                depositCurrencyConversionRate[depositId][verifier][currency.code] = currency.conversionRate;
                depositCurrencies[depositId][verifier].push(currency.code);

                emit DepositCurrencyAdded(depositId, verifier, currency.code, currency.conversionRate);
            }
        }

        _token.transferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @notice Only callable by the depositor for a deposit. Allows depositor to update the conversion rate for a currency for a
     * payment verifier. Since intent's store the conversion rate at the time of intent, changing the conversion rate will not affect
     * any intents that have already been signaled.
     */
    function updateDepositConversionRate() {
    }

    // *** Governance functions ***

    function addVerifier(
        address _verifier
    ) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        verifiers.push(_verifier);
    }

    function removeVerifier(
        address _verifier
    ) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        require(verifiers.length > 0, "No verifiers to remove");

        for (uint256 i = 0; i < verifiers.length; i++) {
            if (verifiers[i] == _verifier) {
                verifiers[i] = verifiers[verifiers.length - 1];
                verifiers.pop();
                break;
            }
        }
    }

    function setVerifierData(
        address _verifier,
        string calldata _payeeDetails,
        bytes calldata _data
    ) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        depositVerifierData[_verifier] = DepositVerifierData({
            payeeDetails: _payeeDetails,
            data: _data
        });
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /* ============ Internal Functions ============ */
    function _validateCreateDeposit(
        uint256 _amount,
        Range memory _intentAmountRange,
        address[] calldata _verifiers,
        DepositVerifierData[] calldata _verifierData,
        Currency[][] calldata _currencies
    ) internal view {
        require(_intentAmountRange.min != 0, "Invalid intent amount range");
        require(_intentAmountRange.min <= _intentAmountRange.max, "Invalid intent amount range");
        require(_intentAmountRange.min <= _amount, "Amount must be greater than min intent amount");
        require(_verifiers.length > 0, "Invalid verifiers");
        require(_verifiers.length == _verifierData.length, "Invalid verifier data");
    }

    function _pruneIntent(uint256 _intentId) internal {
        delete accountIntent[intents[_intentId].owner];
        delete intents[_intentId];
    }

    function _pruneRedeemRequest(uint256 _redeemId) internal {
        delete accountRedeemRequest[redeemRequests[_redeemId].owner];
        delete redeemRequests[_redeemId];
        Intent memory intent = intents[_intentHash];
        Deposit storage deposit = deposits[intent.depositId];
    }

    function _transferFunds(IERC20 _token, Intent memory _intent) internal {
        uint256 fee;
        uint256 transferAmount = _intent.amount - fee;
        _token.transfer(_intent.to, transferAmount);
    }
}

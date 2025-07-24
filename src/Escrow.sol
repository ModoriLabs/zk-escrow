//SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IPaymentVerifierV2 } from "./verifiers/interfaces/IPaymentVerifierV2.sol";
import { IEscrow } from "./interfaces/IEscrow.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IMintableERC20 } from "./interfaces/IMintableERC20.sol";
import { StringUtils } from "./external/ReclaimStringUtils.sol";
import { Uint256ArrayUtils } from "./external/Uint256ArrayUtils.sol";

contract Escrow is Ownable, Pausable, IEscrow {
    using Uint256ArrayUtils for uint256[];

    string public chainIdStr;
    uint256 public intentCount;

    // Mapping of address to intentHash (Only one intent per address at a given time)
    mapping(address => uint256[]) public accountDeposits;
    mapping(address => uint256) public accountIntent;

    mapping(uint256 => Deposit) public deposits;
    mapping(uint256 => Intent) public intents;
    mapping(uint256 => address[]) public depositVerifiers;
    mapping(uint256 depositId => mapping(address => DepositVerifierData)) public depositVerifierData;

    // Mapping of depositId to verifier address to mapping of fiat currency to conversion rate. Each payment service can support
    // multiple currencies. Depositor can specify list of currencies and conversion rates for each payment service.
    // Example: Deposit 1 => Venmo => USD: 1e18
    //                    => Revolut => USD: 1e18, EUR: 1.2e18, SGD: 1.5e18
    mapping(uint256 depositId => mapping(address verifier => mapping(bytes32 fiatCurrency => uint256 conversionRate))) public depositCurrencyConversionRate;
    mapping(uint256 depositId => mapping(address verifier => bytes32[] fiatCurrencies)) public depositCurrencies; // Handy mapping to get all currencies for a deposit and verifier

    // Governance controlled
    mapping(address => bool) public whitelistedPaymentVerifiers;      // Mapping of payment verifier addresses to boolean indicating if they are whitelisted

    uint256 public intentExpirationPeriod;
    uint256 public depositCounter;
    uint256 public maxIntentsPerDeposit;

    constructor(
        address _owner,
        uint256 _intentExpirationPeriod
    ) Ownable(_owner) {
        intentExpirationPeriod = _intentExpirationPeriod;
        maxIntentsPerDeposit = 100; // Default max intents per deposit
        chainIdStr = StringUtils.uint2str(block.chainid);
    }

    function signalIntent(
        uint256 _depositId,
        uint256 _amount,
        address _to,
        address _verifier,
        bytes32 _fiatCurrency
    ) external whenNotPaused {
        Deposit storage deposit = deposits[_depositId];

        _validateIntent(_depositId, deposit, _amount, _to, _verifier, _fiatCurrency);

        require(deposit.intentIds.length <= maxIntentsPerDeposit, "Maximum intents per deposit reached");

        uint256 intentId = ++intentCount;

        if (deposit.remainingDeposits < _amount) {
            (
                uint256[] memory prunableIntents,
                uint256 reclaimableAmount
            ) = _getPrunableIntents(_depositId);

            require(deposit.remainingDeposits + reclaimableAmount >= _amount, "Not enough liquidity");

            _pruneIntents(deposit, prunableIntents);
            deposit.remainingDeposits += reclaimableAmount;
            deposit.outstandingIntentAmount -= reclaimableAmount;
        }

        uint256 conversionRate = depositCurrencyConversionRate[_depositId][_verifier][_fiatCurrency];
        intents[intentId] = Intent({
            owner: msg.sender,
            to: _to,
            depositId: _depositId,
            amount: _amount,
            paymentVerifier: _verifier,
            fiatCurrency: _fiatCurrency,
            conversionRate: conversionRate,
            timestamp: block.timestamp
        });

        accountIntent[msg.sender] = intentId;

        deposit.remainingDeposits -= _amount;
        deposit.outstandingIntentAmount += _amount;
        deposit.intentIds.push(intentId);

        emit IntentSignaled(_to, _verifier, _amount, intentId);
    }

    /**
     * @notice Only callable by the originator of the intent. Allowed even when paused.
     *
     * @param _intentId    ID of intent being cancelled
     */
    function cancelIntent(uint256 _intentId) external {
        Intent memory intent = intents[_intentId];
        Deposit storage deposit = deposits[intent.depositId];
        require(intent.owner == msg.sender, "Sender must be the intent owner");

        _pruneIntent(deposit, _intentId);

        deposit.remainingDeposits += intent.amount;
        deposit.outstandingIntentAmount -= intent.amount;

        emit IntentCancelled(_intentId);
    }

    function fulfillIntent(
        bytes calldata _paymentProof,
        uint256 _intentId
    ) external whenNotPaused {
        Intent memory intent = intents[_intentId];
        Deposit storage deposit = deposits[intent.depositId];

        address verifier = intent.paymentVerifier;
        require(verifier != address(0), IntentNotFound());

        DepositVerifierData memory verifierData = depositVerifierData[intent.depositId][verifier];
        (bool success, bytes32 intentHash) = IPaymentVerifierV2(verifier).verifyPayment(
            IPaymentVerifierV2.VerifyPaymentData({
                paymentProof: _paymentProof,
                depositToken: address(deposit.token),
                intentAmount: intent.amount,
                intentTimestamp: intent.timestamp,
                payeeDetails: verifierData.payeeDetails,
                fiatCurrency: intent.fiatCurrency,
                conversionRate: intent.conversionRate,
                data: verifierData.data
            })
        );
        require(success, "Payment verification failed");

        bytes32 expectedIntentHash = keccak256(abi.encode(string.concat(chainIdStr, "-", StringUtils.uint2str(_intentId))));
        require(expectedIntentHash == intentHash, "Intent hash mismatch");

        _pruneIntent(deposit, _intentId);
        deposit.outstandingIntentAmount -= intent.amount;
        IERC20 token = deposit.token;

        _transferFunds(IERC20(token), intent);

        emit IntentFulfilled(
            _intentId,
            intent.depositId,
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
    ) external whenNotPaused returns(uint256 depositId) {
        _validateCreateDeposit(_amount, _intentAmountRange, _verifiers, _verifierData, _currencies);

        depositId = ++depositCounter;
        accountDeposits[msg.sender].push(depositId);

        deposits[depositId] = Deposit({
            depositor: msg.sender,
            token: _token,
            amount: _amount,
            intentAmountRange: _intentAmountRange,
            acceptingIntents: true,
            intentIds: new uint256[](0),
            remainingDeposits: _amount,
            outstandingIntentAmount: 0
        });

        emit DepositCreated(depositId, msg.sender, _token, _amount, _intentAmountRange);

        for (uint256 i = 0; i < _verifiers.length; i++) {
            address verifier = _verifiers[i];
            require(
                bytes(depositVerifierData[depositId][verifier].payeeDetails).length == 0,
                "Verifier data already exists"
            );
            depositVerifierData[depositId][verifier] = _verifierData[i];
            depositVerifiers[depositId].push(verifier);

            bytes32 payeeDetailsHash = keccak256(abi.encodePacked(_verifierData[i].payeeDetails));
            emit DepositVerifierAdded(depositId, verifier, payeeDetailsHash);

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

    function releaseFundsToPayer(uint256 _intentId) external {
        Intent memory intent = intents[_intentId];
        Deposit storage deposit = deposits[intent.depositId];

        require(intent.owner != address(0), "Intent does not exist");
        require(deposit.depositor == msg.sender, "Caller must be the depositor");

        _pruneIntent(deposit, _intentId);

        deposit.outstandingIntentAmount -= intent.amount;
        IERC20 token = deposit.token;

        _transferFunds(token, intent);

        emit IntentReleased(
            _intentId,
            intent.depositId,
            intent.owner,
            intent.to,
            intent.amount
        );
    }

    /**
     * @notice Only callable by the depositor for a deposit. Allows depositor to update the conversion rate for a currency for a
     * payment verifier. Since intent's store the conversion rate at the time of intent, changing the conversion rate will not affect
     * any intents that have already been signaled.
     */
    function updateDepositConversionRate(
        uint256 _depositId,
        address _verifier,
        bytes32 _fiatCurrency,
        uint256 _newConversionRate
    ) external whenNotPaused {
        Deposit storage deposit = deposits[_depositId];
        uint256 oldConversionRate = depositCurrencyConversionRate[_depositId][_verifier][_fiatCurrency];

        require(deposit.depositor == msg.sender, OnlyDepositor());
        require(oldConversionRate != 0, "Currency or verifier not supported");
        require(_newConversionRate > 0, "Conversion rate must be greater than 0");

        depositCurrencyConversionRate[_depositId][_verifier][_fiatCurrency] = _newConversionRate;

        emit DepositConversionRateUpdated(_depositId, _verifier, _fiatCurrency, _newConversionRate);
    }

    function withdrawDeposit(uint256 _depositId) external {
        Deposit storage deposit = deposits[_depositId];

        require(deposit.depositor == msg.sender, "Caller must be the depositor");

        (
            uint256[] memory prunableIntents,
            uint256 reclaimableAmount
        ) = _getPrunableIntents(_depositId);

        _pruneIntents(deposit, prunableIntents);

        uint256 returnAmount = deposit.remainingDeposits + reclaimableAmount;

        deposit.outstandingIntentAmount -= reclaimableAmount;

        emit DepositWithdrawn(_depositId, deposit.depositor, returnAmount);

        delete deposit.remainingDeposits;
        delete deposit.acceptingIntents;
        _closeDepositIfNecessary(_depositId, deposit);

        IERC20(deposit.token).transfer(msg.sender, returnAmount);
    }

    /**
     * @notice Allows the depositor to add more funds to an existing deposit.
     * The depositor must approve the escrow contract to transfer the additional amount.
     *
     * @param _depositId The ID of the deposit to increase
     * @param _amount The additional amount to add to the deposit
     */
    function increaseDeposit(uint256 _depositId, uint256 _amount) external whenNotPaused {
        Deposit storage deposit = deposits[_depositId];

        require(deposit.depositor == msg.sender, "Caller must be the depositor");
        require(deposit.depositor != address(0), "Deposit does not exist");
        require(_amount > 0, "Amount must be greater than 0");
        require(deposit.acceptingIntents, "Deposit is not accepting intents");

        IERC20 token = deposit.token;

        // Transfer additional funds from depositor to escrow
        token.transferFrom(msg.sender, address(this), _amount);

        // Update deposit state
        deposit.amount += _amount;
        deposit.remainingDeposits += _amount;

        emit DepositIncreased(_depositId, msg.sender, _amount, deposit.amount);
    }

    // *** Governance functions ***

        /**
     * @notice GOVERNANCE ONLY: Adds a payment verifier to the whitelist.
     *
     * @param _verifier   The payment verifier address to add
     */
    function addWhitelistedPaymentVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), "Payment verifier cannot be zero address");
        require(!whitelistedPaymentVerifiers[_verifier], "Payment verifier already whitelisted");

        whitelistedPaymentVerifiers[_verifier] = true;

        emit PaymentVerifierAdded(_verifier);
    }

    /**
     * @notice GOVERNANCE ONLY: Removes a payment verifier from the whitelist.
     *
     * @param _verifier   The payment verifier address to remove
     */
    function removeWhitelistedPaymentVerifier(address _verifier) external onlyOwner {
        require(whitelistedPaymentVerifiers[_verifier], "Payment verifier not whitelisted");

        whitelistedPaymentVerifiers[_verifier] = false;
        emit PaymentVerifierRemoved(_verifier);
    }

    /**
     * @notice GOVERNANCE ONLY: Updates the maximum number of intents allowed per deposit.
     *
     * @param _maxIntentsPerDeposit The new maximum number of intents allowed per deposit
     */
    function setMaxIntentsPerDeposit(uint256 _maxIntentsPerDeposit) external onlyOwner {
        require(_maxIntentsPerDeposit > 0, "Max intents must be greater than 0");
        uint256 oldMax = maxIntentsPerDeposit;
        maxIntentsPerDeposit = _maxIntentsPerDeposit;
        emit MaxIntentsPerDepositUpdated(oldMax, _maxIntentsPerDeposit);
    }

    /**
     * @notice GOVERNANCE ONLY: Updates the intent expiration period, after this period elapses an intent can be pruned to prevent
     * locking up a depositor's funds.
     *
     * @param _intentExpirationPeriod   New intent expiration period
     */
    function setIntentExpirationPeriod(uint256 _intentExpirationPeriod) external onlyOwner {
        require(_intentExpirationPeriod != 0, "Max intent expiration period cannot be zero");

        intentExpirationPeriod = _intentExpirationPeriod;
        emit IntentExpirationPeriodSet(_intentExpirationPeriod);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
    /* ============ External View Functions ============ */

    // Getter functions for easier testing
    function getDepositIntentIds(uint256 _depositId) external view returns (uint256[] memory) {
        return deposits[_depositId].intentIds;
    }

    /* ============ Internal Functions ============ */
    function _validateCreateDeposit(
        uint256 _amount,
        Range memory _intentAmountRange,
        address[] calldata _verifiers,
        DepositVerifierData[] calldata _verifierData,
        Currency[][] calldata _currencies
    ) internal pure {
        require(_intentAmountRange.min != 0, "Invalid intent amount range");
        require(_intentAmountRange.min <= _intentAmountRange.max, "Invalid intent amount range");
        require(_intentAmountRange.min <= _amount, "Amount must be greater than min intent amount");
        require(_verifiers.length > 0, "Invalid verifiers");
        require(_verifiers.length == _verifierData.length, "Invalid verifier data");
        require(_verifiers.length == _currencies.length, "Invalid currencies length");
    }

    function _validateIntent(
        uint256 _depositId,
        Deposit storage _deposit,
        uint256 _amount,
        address _to,
        address _verifier,
        bytes32 _fiatCurrency
    ) internal view {
        require(accountIntent[msg.sender] == 0, IntentAlreadyExists());
        require(_deposit.depositor != address(0), "Deposit does not exist");
        require(_deposit.acceptingIntents, "Deposit is not accepting intents");
        require(_amount >= _deposit.intentAmountRange.min, InvalidAmount());
        require(_amount <= _deposit.intentAmountRange.max, InvalidAmount());
        require(_to != address(0), InvalidRecipient());

        DepositVerifierData memory verifierData = depositVerifierData[_depositId][_verifier];
        require(bytes(verifierData.payeeDetails).length != 0, "Payment verifier not supported");
        require(depositCurrencyConversionRate[_depositId][_verifier][_fiatCurrency] != 0, "Currency not supported");
    }

    /**
     * @notice Cycles through all intents currently open on a deposit and sees if any have expired. If they have expired
     * the outstanding amounts are summed and returned alongside the intentHashes
     */
    function _getPrunableIntents(
        uint256 _depositId
    )
        internal
        view
        returns(uint256[] memory prunableIntents, uint256 reclaimedAmount)
    {
        uint256[] memory intentIds = deposits[_depositId].intentIds;
        prunableIntents = new uint256[](intentIds.length);

        for (uint256 i = 0; i < intentIds.length; ++i) {
            Intent memory intent = intents[intentIds[i]];
            if (intent.timestamp + intentExpirationPeriod < block.timestamp) {
                prunableIntents[i] = intentIds[i];
                reclaimedAmount += intent.amount;
            }
        }
    }

    function _pruneIntents(Deposit storage _deposit, uint256[] memory _intents) internal {
        for (uint256 i = 0; i < _intents.length; ++i) {
            if (_intents[i] != 0) {
                _pruneIntent(_deposit, _intents[i]);
            }
        }
    }

    /**
     * @notice Pruning an intent involves
     * 1. deleting its state from the intents mapping
     * 2. deleting the intent from it's owners intents array
     * 3. deleting the intentHash from the deposit's intentHashes array.
     */
    function _pruneIntent(Deposit storage _deposit, uint256 _intentId) internal {
        Intent memory intent = intents[_intentId];

        delete accountIntent[intent.owner];
        delete intents[_intentId];
        _deposit.intentIds.removeStorage(_intentId);
    }

    /**
     * @notice Removes a deposit if no outstanding intents AND no remaining deposits. Deleting a deposit deletes it from the
     * deposits mapping and removes tracking it in the user's accountDeposits mapping. Also deletes the verification data for the
     * deposit.
     */
    function _closeDepositIfNecessary(uint256 _depositId, Deposit storage _deposit) internal {
        uint256 openDepositAmount = _deposit.outstandingIntentAmount + _deposit.remainingDeposits;
        if (openDepositAmount == 0) {
            accountDeposits[_deposit.depositor].removeStorage(_depositId);
            _deleteDepositVerifierAndCurrencyData(_depositId);
            emit DepositClosed(_depositId, _deposit.depositor);
            delete deposits[_depositId];
        }
    }

    /**
     * @notice Iterates through all verifiers for a deposit and deletes the corresponding verifier data and currencies.
     */
    function _deleteDepositVerifierAndCurrencyData(uint256 _depositId) internal {
        address[] memory verifiers = depositVerifiers[_depositId];
        for (uint256 i = 0; i < verifiers.length; i++) {
            address verifier = verifiers[i];
            delete depositVerifierData[_depositId][verifier];
            bytes32[] memory currencies = depositCurrencies[_depositId][verifier];
            for (uint256 j = 0; j < currencies.length; j++) {
                delete depositCurrencyConversionRate[_depositId][verifier][currencies[j]];
            }
        }
    }

    function _transferFunds(IERC20 _token, Intent memory _intent) internal {
        uint256 fee;
        uint256 transferAmount = _intent.amount - fee;
        _token.transfer(_intent.to, transferAmount);
    }
}

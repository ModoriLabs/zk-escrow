// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { DateParsing } from "../lib/DateParsing.sol";
import { ClaimVerifier } from "../lib/ClaimVerifier.sol";
import { StringConversionUtils } from "../lib/StringConversionUtils.sol";
import { Bytes32ConversionUtils } from "../lib/Bytes32ConversionUtils.sol";

import { BaseReclaimPaymentVerifier } from "./BaseReclaimPaymentVerifier.sol";
import { INullifierRegistry } from "./nullifierRegistries/INullifierRegistry.sol";
import { IPaymentVerifierV2 } from "./interfaces/IPaymentVerifierV2.sol";

contract TossBankReclaimVerifierV2 is IPaymentVerifierV2, BaseReclaimPaymentVerifier {

    using StringConversionUtils for string;
    using Bytes32ConversionUtils for bytes32;

    /* ============ State Variables ============ */

    // Mapping to track authorized escrows
    mapping(address => bool) public isEscrow;
    // Array to store all escrows for enumeration
    address[] public escrows;

    /* ============ Events ============ */

    event EscrowAdded(address indexed escrow);
    event EscrowRemoved(address indexed escrow);

    /* ============ Structs ============ */

    // Struct to hold the payment details extracted from the proof
    struct PaymentDetails {
        string amountString;
        string dateString;
        string senderNickname;
        string recipientBankAccount;
        string providerHash;
    }

    /* ============ Constants ============ */

    // 11 extracted parameters + 1 providerHash
    uint8 internal constant MAX_EXTRACT_VALUES = 12;
    uint8 internal constant MIN_WITNESS_SIGNATURE_REQUIRED = 1;
    bytes32 internal constant KRW_CURRENCY = keccak256("KRW");

    /* ============ Constructor ============ */
    constructor(
        address _owner,
        address _escrow,
        INullifierRegistry _nullifierRegistry,
        uint256 _timestampBuffer,
        bytes32[] memory _currencies,
        string[] memory _providerHashes
    )
        BaseReclaimPaymentVerifier(
            _owner,
            _escrow,
            _nullifierRegistry,
            _timestampBuffer,
            _currencies,
            _providerHashes
        )
    {
        // Add initial escrow
        isEscrow[_escrow] = true;
        escrows.push(_escrow);
        emit EscrowAdded(_escrow);
    }

    function verifyPayment(
        VerifyPaymentData calldata _verifyPaymentData
    )
        external
        override
        returns (bool, bytes32)
    {
        require(isEscrow[msg.sender], "Only escrows can call");

        (
            PaymentDetails memory paymentDetails,
            bool isAppclipProof
        ) = _verifyProofAndExtractValues(_verifyPaymentData.paymentProof, _verifyPaymentData.data);

        _verifyPaymentDetails(paymentDetails, _verifyPaymentData, isAppclipProof);

        bytes32 nullifier = keccak256(
            abi.encodePacked(paymentDetails.dateString, paymentDetails.senderNickname)
        );
        _validateAndAddNullifier(nullifier);

        return (true, keccak256(abi.encode(paymentDetails.senderNickname)));
    }

    function _verifyProofAndExtractValues(bytes calldata _proof, bytes calldata _depositData)
        internal
        view
        returns (PaymentDetails memory paymentDetails, bool isAppclipProof)
    {
        // Decode proof
        ReclaimProof memory proof = abi.decode(_proof, (ReclaimProof));

        // Extract verification data
        address[] memory witnesses = _decodeDepositData(_depositData);

        verifyProofSignatures(proof, witnesses, MIN_WITNESS_SIGNATURE_REQUIRED);     // claim must have at least 1 signature from witnesses

        // Extract public values
        paymentDetails = _extractValues(proof);

        // Check provider hash (Required for Reclaim proofs)
        require(_validateProviderHash(paymentDetails.providerHash), "No valid providerHash");

        isAppclipProof = proof.isAppclipProof;
    }

    function _decodeDepositData(bytes calldata _data) internal pure returns (address[] memory witnesses) {
        witnesses = abi.decode(_data, (address[]));
    }

    /**
     * Verifies the payment details.
     * @param paymentDetails The payment details extracted from the proof.
     * @param _verifyPaymentData The verify payment data from the escrow.
     * @param _isAppclipProof Whether the proof is an appclip proof.
     */
    function _verifyPaymentDetails(
        PaymentDetails memory paymentDetails,
        VerifyPaymentData memory _verifyPaymentData,
        bool _isAppclipProof
    ) internal view {
        uint256 expectedAmount = _verifyPaymentData.intentAmount * _verifyPaymentData.conversionRate / PRECISE_UNIT;
        uint8 decimals = IERC20Metadata(_verifyPaymentData.depositToken).decimals();

        uint256 paymentAmount = paymentDetails.amountString.stringToUint(decimals);
        require(paymentAmount >= expectedAmount, "Incorrect payment amount");

        // Validate recipient
        if (_isAppclipProof) {
            bytes32 hashedRecipientId = keccak256(abi.encodePacked(paymentDetails.recipientBankAccount));
            require(
                hashedRecipientId.toHexString().stringComparison(_verifyPaymentData.payeeDetails),
                "Incorrect payment recipient"
            );
        } else {
            require(
                paymentDetails.recipientBankAccount.stringComparison(_verifyPaymentData.payeeDetails),
                "Incorrect payment recipient"
            );
        }

        // Validate timestamp
        uint256 paymentTimestamp = _adjustTimestamp(paymentDetails.dateString);
        require(paymentTimestamp >= _verifyPaymentData.intentTimestamp, "Incorrect payment timestamp");

        // Validate currency
        require(_verifyPaymentData.fiatCurrency == KRW_CURRENCY, "Incorrect payment currency");
    }

    /**
     * Adjusts the timestamp to UTC+9 and adds the timestamp buffer to build flexibility for L2 timestamps.
     * @param _dateString The date string to adjust.
     * @return The adjusted timestamp.
    */
    function _adjustTimestamp(string memory _dateString) internal view returns (uint256) {
        uint256 paymentTimestamp = DateParsing._dateStringToTimestamp(_dateString) + timestampBuffer;
        paymentTimestamp = paymentTimestamp - 9 * 60 * 60; // UTC+9
        return paymentTimestamp;
    }

    /**
     * Adds a new escrow address.
     * @param _escrow The escrow address to add.
     */
    function addEscrow(address _escrow) external onlyOwner {
        require(!isEscrow[_escrow], "Already an escrow");
        require(_escrow != address(0), "Invalid escrow address");
        
        isEscrow[_escrow] = true;
        escrows.push(_escrow);
        
        emit EscrowAdded(_escrow);
    }

    /**
     * Removes an escrow address.
     * @param _escrow The escrow address to remove.
     */
    function removeEscrow(address _escrow) external onlyOwner {
        require(isEscrow[_escrow], "Not an escrow");
        
        isEscrow[_escrow] = false;
        
        // Remove from array
        for (uint256 i = 0; i < escrows.length; i++) {
            if (escrows[i] == _escrow) {
                escrows[i] = escrows[escrows.length - 1];
                escrows.pop();
                break;
            }
        }
        
        emit EscrowRemoved(_escrow);
    }

    /**
     * Returns all escrow addresses.
     * @return The array of escrow addresses.
     */
    function getEscrows() external view returns (address[] memory) {
        return escrows;
    }

    /**
     * Extracts all values from the proof context.
     *
     * @param _proof The proof containing the context to extract values from.
     */
    function _extractValues(ReclaimProof memory _proof) internal pure returns (PaymentDetails memory paymentDetails) {
        string[] memory values = ClaimVerifier.extractAllFromContext(
            _proof.claimInfo.context,
            MAX_EXTRACT_VALUES,
            true
        );

        return PaymentDetails({
            // values[0] is documentTitle
            recipientBankAccount: values[1],
            // values[2] is recipientName
            senderNickname: values[3],
            amountString: values[4],
            dateString: values[5],
            providerHash: values[6]
        });
    }
}

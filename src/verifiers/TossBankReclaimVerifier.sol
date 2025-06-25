// SPDX-License-Identifier: MIT

pragma solidity 0.8.29;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { DateParsing } from "../lib/DateParsing.sol";
import { ClaimVerifier } from "../lib/ClaimVerifier.sol";
import { StringConversionUtils } from "../lib/StringConversionUtils.sol";
import { Bytes32ConversionUtils } from "../lib/Bytes32ConversionUtils.sol";

import { BaseReclaimPaymentVerifier } from "./BaseReclaimPaymentVerifier.sol";
import { INullifierRegistry } from "./nullifierRegistries/INullifierRegistry.sol";
import { IPaymentVerifier } from "./interfaces/IPaymentVerifier.sol";
import { console } from "forge-std/src/console.sol";

contract TossBankReclaimVerifier is IPaymentVerifier, BaseReclaimPaymentVerifier {

    using StringConversionUtils for string;
    using Bytes32ConversionUtils for bytes32;

    /* ============ Structs ============ */

    // Struct to hold the payment details extracted from the proof
    struct PaymentDetails {
        string amountString;
        string dateString;
        string senderNickname;
        string recipientBankAccount;
    }

    /* ============ Constants ============ */

    // 11 extracted parameters + 1 providerHash
    uint8 internal constant MAX_EXTRACT_VALUES = 12;
    uint8 internal constant MIN_WITNESS_SIGNATURE_REQUIRED = 1;

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
    { }

    function verifyPayment(
        VerifyPaymentData calldata _verifyPaymentData
    )
        external
        override
        returns (bool, bytes32)
    {
        require(msg.sender == escrow, "Only escrow can call");

        (
            PaymentDetails memory paymentDetails,
            bool isAppclipProof
        ) = _verifyProofAndExtractValues(_verifyPaymentData.paymentProof, _verifyPaymentData.data);

        _verifyPaymentDetails(paymentDetails, _verifyPaymentData, isAppclipProof);

        bytes32 nullifier = keccak256(
            abi.encodePacked(paymentDetails.dateString, paymentDetails.senderNickname)
        );
        console.logBytes32(nullifier);
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

        // FIXME: uncomment
        // Check provider hash (Required for Reclaim proofs)
        // require(_validateProviderHash(paymentDetails.providerHash), "No valid providerHash");

        isAppclipProof = proof.isAppclipProof;
    }

    function _decodeDepositData(bytes calldata _data) internal pure returns (address[] memory witnesses) {
        witnesses = abi.decode(_data, (address[]));
    }

    function _verifyPaymentDetails(
        PaymentDetails memory paymentDetails,
        VerifyPaymentData memory _verifyPaymentData,
        bool _isAppclipProof
    ) internal view {
        uint256 expectedAmount = _verifyPaymentData.intentAmount * _verifyPaymentData.conversionRate / PRECISE_UNIT;
        uint8 decimals = IERC20Metadata(_verifyPaymentData.mintToken).decimals();

        uint256 paymentAmount = paymentDetails.amountString.stringToUint(decimals);
        require(paymentAmount >= expectedAmount, "Incorrect payment amount");

        // Validate recipient
        // TODO: Is it necessary?

        // Validate timestamp; add in buffer to build flexibility for L2 timestamps
        uint256 paymentTimestamp = DateParsing._dateStringToTimestamp(paymentDetails.dateString) + timestampBuffer;
        require(paymentTimestamp >= _verifyPaymentData.intentTimestamp, "Incorrect payment timestamp");
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
        // TODO: toss dateString is Korean timezone, so we need to convert it to UTC

        return PaymentDetails({
            // values[0] is documentTitle
            recipientBankAccount: values[1],
            // values[2] is senderName
            senderNickname: values[3],
            amountString: values[4],
            dateString: values[5]
            // providerHash:values[6],
        });
    }
}

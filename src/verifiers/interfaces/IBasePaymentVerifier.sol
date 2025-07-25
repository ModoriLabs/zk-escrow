// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IBasePaymentVerifier {
    /* ============ Events ============ */
    event CurrencyAdded(bytes32 indexed currencyCode);
    event CurrencyRemoved(bytes32 indexed currencyCode);
    event TimestampBufferSet(uint256 timestampBuffer);

    /* ============ Functions ============ */
    function getCurrencies() external view returns (bytes32[] memory);
    function isCurrency(bytes32 _currencyCode) external view returns (bool);
}

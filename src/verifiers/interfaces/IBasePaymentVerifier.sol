// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IBasePaymentVerifier {
    /* ============ Events ============ */
    event CurrencyAdded(bytes32 indexed currencyCode);
    event CurrencyRemoved(bytes32 indexed currencyCode);
    event TimestampBufferSet(uint256 timestampBuffer);

    /* ============ Functions ============ */
    function addCurrency(bytes32 _currencyCode) external;
    function removeCurrency(bytes32 _currencyCode) external;
    function setTimestampBuffer(uint256 _timestampBuffer) external;
    function getCurrencies() external view returns (bytes32[] memory);
}

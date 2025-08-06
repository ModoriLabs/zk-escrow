// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Bytes32ArrayUtils } from "../external/Bytes32ArrayUtils.sol";
import { IBasePaymentVerifier } from "./interfaces/IBasePaymentVerifier.sol";
import { INullifierRegistry } from "./nullifierRegistries/INullifierRegistry.sol";

contract BasePaymentVerifier is Ownable, IBasePaymentVerifier {
    using Bytes32ArrayUtils for bytes32[];

    /* ============ State Variables ============ */
    address public escrow;
    INullifierRegistry public nullifierRegistry;
    uint256 public timestampBuffer;

    bytes32[] public currencies;
    mapping(bytes32 => bool) public isCurrency;

    /* ============ Constructor ============ */
    constructor(
        address _owner,
        address _escrow,
        INullifierRegistry _nullifierRegistry,
        uint256 _timestampBuffer,
        bytes32[] memory _currencies
    )
        Ownable(_owner)
    {
        escrow = _escrow;
        nullifierRegistry = _nullifierRegistry;
        timestampBuffer = _timestampBuffer;

        for (uint256 i = 0; i < _currencies.length; i++) {
            currencies.push(_currencies[i]);
            isCurrency[_currencies[i]] = true;
        }
    }

    /* ============ External Functions ============ */
    function addCurrency(bytes32 _currencyCode) external onlyOwner {
        require(!isCurrency[_currencyCode], "Currency already added");

        currencies.push(_currencyCode);
        isCurrency[_currencyCode] = true;

        emit CurrencyAdded(_currencyCode);
    }

    function removeCurrency(bytes32 _currencyCode) external onlyOwner {
        require(isCurrency[_currencyCode], "Currency not added");

        currencies.removeStorage(_currencyCode);
        isCurrency[_currencyCode] = false;

        emit CurrencyRemoved(_currencyCode);
    }

    function setTimestampBuffer(uint256 _timestampBuffer) external onlyOwner {
        timestampBuffer = _timestampBuffer;
        emit TimestampBufferSet(_timestampBuffer);
    }

    /* ============ External View Functions ============ */

    function getCurrencies() external view returns (bytes32[] memory) {
        return currencies;
    }

    /* ============ Internal Functions ============ */

    function _validateAndAddNullifier(bytes32 _nullifier) internal {
        require(!nullifierRegistry.isNullified(_nullifier), "Nullifier has already been used");
        nullifierRegistry.addNullifier(_nullifier);
    }
}

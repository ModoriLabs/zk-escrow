// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/src/Test.sol";
import "forge-std/src/console2.sol";
import "../src/verifiers/BasePaymentVerifier.sol";
import "../src/verifiers/nullifierRegistries/NullifierRegistry.sol";

import { BaseTest } from "./BaseTest.sol";

contract BasePaymentVerifierTest is BaseTest {
    BasePaymentVerifier public basePaymentVerifier;

    address public writer;
    address public attacker;
    address public escrow;

    // Currency constants (mimicking the TypeScript test)
    bytes32 public constant USD = bytes32("USD");
    bytes32 public constant EUR = bytes32("EUR");
    bytes32 public constant AED = bytes32("AED");
    bytes32 public constant SGD = bytes32("SGD");

    uint256 public constant TIMESTAMP_BUFFER = 30;

    function setUp() public virtual override {
        super.setUp();

        writer = makeAddr("writer");
        attacker = makeAddr("attacker");
        escrow = makeAddr("escrow");

        // Create initial currencies array
        bytes32[] memory initialCurrencies = new bytes32[](3);
        initialCurrencies[0] = USD;
        initialCurrencies[1] = EUR;
        initialCurrencies[2] = AED;

        // Deploy the BasePaymentVerifier
        basePaymentVerifier = new BasePaymentVerifier(
            owner,
            escrow,
            nullifierRegistry,
            TIMESTAMP_BUFFER,
            initialCurrencies
        );
    }

    /* ============ Constructor Tests ============ */

    function test_Constructor_SetsOwnerCorrectly() public {
        assertEq(basePaymentVerifier.owner(), owner);
    }

    function test_Constructor_SetsTimestampBufferCorrectly() public {
        assertEq(basePaymentVerifier.timestampBuffer(), TIMESTAMP_BUFFER);
    }

    function test_Constructor_SetsCurrenciesCorrectly() public {
        bytes32[] memory currencies = basePaymentVerifier.getCurrencies();
        assertEq(currencies.length, 3);
        assertEq(currencies[0], USD);
        assertEq(currencies[1], EUR);
        assertEq(currencies[2], AED);

        // Check that currencies are marked as valid
        assertTrue(basePaymentVerifier.isCurrency(USD));
        assertTrue(basePaymentVerifier.isCurrency(EUR));
        assertTrue(basePaymentVerifier.isCurrency(AED));
    }

    function test_Constructor_SetsEscrowCorrectly() public {
        assertEq(basePaymentVerifier.escrow(), escrow);
    }

    function test_Constructor_SetsNullifierRegistryCorrectly() public {
        assertEq(address(basePaymentVerifier.nullifierRegistry()), address(nullifierRegistry));
    }

    /* ============ Add Currency Tests ============ */

    function test_AddCurrency_Success() public {
        vm.expectEmit(true, false, false, true);
        emit IBasePaymentVerifier.CurrencyAdded(SGD);

        vm.prank(owner);
        basePaymentVerifier.addCurrency(SGD);

        assertTrue(basePaymentVerifier.isCurrency(SGD));

        bytes32[] memory currencies = basePaymentVerifier.getCurrencies();
        assertEq(currencies.length, 4);
        assertEq(currencies[3], SGD);
    }

    function test_AddCurrency_RevertWhen_CurrencyAlreadyAdded() public {
        vm.startPrank(owner);
        basePaymentVerifier.addCurrency(SGD);

        vm.expectRevert("Currency already added");
        basePaymentVerifier.addCurrency(SGD);
        vm.stopPrank();
    }

    function test_AddCurrency_RevertWhen_NotOwner() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        basePaymentVerifier.addCurrency(SGD);
    }

    /* ============ Remove Currency Tests ============ */

    function test_RemoveCurrency_Success() public {
        vm.startPrank(owner);
        // First add the currency
        basePaymentVerifier.addCurrency(SGD);
        assertTrue(basePaymentVerifier.isCurrency(SGD));

        vm.expectEmit(true, false, false, true);
        emit IBasePaymentVerifier.CurrencyRemoved(SGD);

        basePaymentVerifier.removeCurrency(SGD);
        vm.stopPrank();

        assertFalse(basePaymentVerifier.isCurrency(SGD));
    }

    function test_RemoveCurrency_RevertWhen_CurrencyNotAdded() public {
        vm.prank(owner);
        vm.expectRevert("Currency not added");
        basePaymentVerifier.removeCurrency(SGD);
    }

    function test_RemoveCurrency_RevertWhen_NotOwner() public {
        vm.prank(owner);
        basePaymentVerifier.addCurrency(SGD);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        basePaymentVerifier.removeCurrency(SGD);
    }

    /* ============ Set Timestamp Buffer Tests ============ */

    function test_SetTimestampBuffer_Success() public {
        uint256 newBuffer = 60;

        vm.expectEmit(false, false, false, true);
        emit IBasePaymentVerifier.TimestampBufferSet(newBuffer);

        vm.prank(owner);
        basePaymentVerifier.setTimestampBuffer(newBuffer);

        assertEq(basePaymentVerifier.timestampBuffer(), newBuffer);
    }

    function test_SetTimestampBuffer_RevertWhen_NotOwner() public {
        uint256 newBuffer = 60;

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        basePaymentVerifier.setTimestampBuffer(newBuffer);
    }

    /* ============ Get Currencies Tests ============ */

    function test_GetCurrencies_ReturnsCorrectCurrencies() public {
        bytes32[] memory currencies = basePaymentVerifier.getCurrencies();

        assertEq(currencies.length, 3);
        assertEq(currencies[0], USD);
        assertEq(currencies[1], EUR);
        assertEq(currencies[2], AED);
    }

    function test_GetCurrencies_UpdatesAfterAddingCurrency() public {
        vm.prank(owner);
        basePaymentVerifier.addCurrency(SGD);

        bytes32[] memory currencies = basePaymentVerifier.getCurrencies();

        assertEq(currencies.length, 4);
        assertEq(currencies[3], SGD);
    }
}

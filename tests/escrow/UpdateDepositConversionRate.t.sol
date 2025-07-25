// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseEscrowTest.sol";

contract UpdateDepositConversionRateTest is BaseEscrowTest {
    uint256 public depositId;
    uint256 public depositAmount = 10000e6; // 10,000 USDT

    function setUp() public override {
        super.setUp();
        // Create a deposit for testing
        depositId = _createDeposit();
    }

    function test_updateDepositConversionRate_UpdateKRWRate() public {
        uint256 oldKrwRate = escrow.depositCurrencyConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW")
        );
        uint256 newKrwRate = 1400e18; // New KRW rate: 1400

        assertEq(oldKrwRate, KRW_CONVERSION_RATE); // Initial KRW rate should be 1380

        // Update KRW conversion rate as depositor
        vm.prank(alice);
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW"),
            newKrwRate
        );

        // Verify the KRW rate was updated
        uint256 updatedKrwRate = escrow.depositCurrencyConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW")
        );
        assertEq(updatedKrwRate, newKrwRate);
    }

    function test_updateDepositConversionRate_RevertNotDepositor() public {
        uint256 newRate = 2e18;

        // Try to update as non-depositor (bob)
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.OnlyDepositor.selector));
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW"),
            newRate
        );
    }

    function test_updateDepositConversionRate_RevertUnsupportedCurrency() public {
        uint256 newRate = 2e18;

        // Try to update rate for unsupported currency (EUR)
        vm.prank(alice);
        vm.expectRevert("Currency or verifier not supported");
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("EUR"), // EUR not supported
            newRate
        );
    }

    function test_updateDepositConversionRate_RevertUnsupportedVerifier() public {
        uint256 newRate = 2e18;
        address unsupportedVerifier = makeAddr("unsupportedVerifier");

        // Try to update rate for unsupported verifier
        vm.prank(alice);
        vm.expectRevert("Currency or verifier not supported");
        escrow.updateDepositConversionRate(
            depositId,
            unsupportedVerifier,
            keccak256("KRW"),
            newRate
        );
    }

    function test_updateDepositConversionRate_RevertZeroRate() public {
        uint256 zeroRate = 0;

        // Try to update with zero rate
        vm.prank(alice);
        vm.expectRevert("Conversion rate must be greater than 0");
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW"),
            zeroRate
        );
    }

    function test_updateDepositConversionRate_RevertNonExistentDeposit() public {
        uint256 nonExistentDepositId = 999;
        uint256 newRate = 2e18;

        // Try to update rate for non-existent deposit
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.OnlyDepositor.selector));
        escrow.updateDepositConversionRate(
            nonExistentDepositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW"),
            newRate
        );
    }

    function test_updateDepositConversionRate_RevertWhenPaused() public {
        uint256 newRate = 2e18;

        // Pause the contract
        vm.prank(escrowOwner);
        escrow.pause();

        // Try to update rate when paused
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW"),
            newRate
        );
    }

    function test_updateDepositConversionRate_MultipleUpdates() public {
        uint256 firstRate = 1.5e18;
        uint256 secondRate = 2.5e18;
        uint256 thirdRate = 1.8e18;

        // First update
        vm.prank(alice);
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW"),
            firstRate
        );

        uint256 rate1 = escrow.depositCurrencyConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW")
        );
        assertEq(rate1, firstRate);

        // Second update
        vm.prank(alice);
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW"),
            secondRate
        );

        uint256 rate2 = escrow.depositCurrencyConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW")
        );
        assertEq(rate2, secondRate);

        // Third update
        vm.prank(alice);
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW"),
            thirdRate
        );

        uint256 rate3 = escrow.depositCurrencyConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW")
        );
        assertEq(rate3, thirdRate);
    }

    function test_updateDepositConversionRate_AffectsNewIntents() public {
        uint256 newUsdRate = 2e18; // 2.0 conversion rate
        uint256 intentAmount = 1000e6; // 1000 USDT

        // Update USD conversion rate
        vm.prank(alice);
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW"),
            newUsdRate
        );

        // Signal new intent - should use updated conversion rate
        vm.prank(bob);
        escrow.signalIntent(
            depositId,
            intentAmount,
            bob,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW")
        );

        uint256 intentId = escrow.accountIntent(bob);

        // Check that intent uses the updated conversion rate
        (,,,,,, , uint256 conversionRate) = escrow.intents(intentId);
        assertEq(conversionRate, newUsdRate);
    }

    function test_updateDepositConversionRate_DoesNotAffectExistingIntents() public {
        uint256 intentAmount = 1000e6; // 1000 USDT
        uint256 originalRate = KRW_CONVERSION_RATE;

        // Signal intent with original conversion rate
        vm.prank(bob);
        escrow.signalIntent(
            depositId,
            intentAmount,
            bob,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW")
        );

        uint256 intentId = escrow.accountIntent(bob);

        // Check original conversion rate in intent
        (,,,,,, , uint256 originalConversionRate) = escrow.intents(intentId);
        assertEq(originalConversionRate, originalRate);

        // Update conversion rate after intent creation
        uint256 newRate = 2e18;
        vm.prank(alice);
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW"),
            newRate
        );

        // Check that existing intent still has original conversion rate
        (,,,,,, , uint256 unchangedConversionRate) = escrow.intents(intentId);
        assertEq(unchangedConversionRate, originalRate);

        // Verify deposit has new rate
        uint256 depositRate = escrow.depositCurrencyConversionRate(
            depositId,
            address(tossBankReclaimVerifierV2),
            keccak256("KRW")
        );
        assertEq(depositRate, newRate);
    }
}

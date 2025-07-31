// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./BaseEscrowTest.sol";

contract EscrowTest is BaseEscrowTest {
    function setUp() public override {
        super.setUp();

        escrowOwner = escrow.owner();
        usdtOwner = usdt.owner();

        vm.startPrank(usdtOwner);
        usdt.mint(alice, 100_000e6); // 100,000 USDT
        usdt.mint(bob, 50_000e6); // 50,000 USDT
        vm.stopPrank();
    }

    // ============ Only Owner Function Tests ============

    function test_addWhitelistedPaymentVerifier_Success() public {
        address newVerifier = makeAddr("newVerifier");

        // Verify not whitelisted initially
        assertFalse(escrow.whitelistedPaymentVerifiers(newVerifier));

        // Add verifier as owner
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IEscrow.PaymentVerifierAdded(newVerifier);
        escrow.addWhitelistedPaymentVerifier(newVerifier);

        // Verify whitelisted
        assertTrue(escrow.whitelistedPaymentVerifiers(newVerifier));
    }

    function test_addWhitelistedPaymentVerifier_RevertNonOwner() public {
        address newVerifier = makeAddr("newVerifier");

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        escrow.addWhitelistedPaymentVerifier(newVerifier);
    }

    function test_addWhitelistedPaymentVerifier_RevertZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Payment verifier cannot be zero address");
        escrow.addWhitelistedPaymentVerifier(address(0));
    }

    function test_addWhitelistedPaymentVerifier_RevertAlreadyWhitelisted() public {
        address newVerifier = makeAddr("newVerifier");

        // Add verifier first time
        vm.prank(owner);
        escrow.addWhitelistedPaymentVerifier(newVerifier);

        // Try to add again
        vm.prank(owner);
        vm.expectRevert("Payment verifier already whitelisted");
        escrow.addWhitelistedPaymentVerifier(newVerifier);
    }

    function test_removeWhitelistedPaymentVerifier_Success() public {
        // First add a verifier
        address verifierToRemove = makeAddr("verifierToRemove");
        vm.prank(owner);
        escrow.addWhitelistedPaymentVerifier(verifierToRemove);
        assertTrue(escrow.whitelistedPaymentVerifiers(verifierToRemove));

        // Remove verifier
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IEscrow.PaymentVerifierRemoved(verifierToRemove);
        escrow.removeWhitelistedPaymentVerifier(verifierToRemove);

        // Verify removed
        assertFalse(escrow.whitelistedPaymentVerifiers(verifierToRemove));
    }

    function test_removeWhitelistedPaymentVerifier_RevertNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        escrow.removeWhitelistedPaymentVerifier(address(tossBankReclaimVerifier));
    }

    function test_removeWhitelistedPaymentVerifier_RevertNotWhitelisted() public {
        address notWhitelisted = makeAddr("notWhitelisted");

        vm.prank(owner);
        vm.expectRevert("Payment verifier not whitelisted");
        escrow.removeWhitelistedPaymentVerifier(notWhitelisted);
    }

    function test_setIntentExpirationPeriod_Success() public {
        uint256 newPeriod = 7 days;

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IEscrow.IntentExpirationPeriodSet(newPeriod);
        escrow.setIntentExpirationPeriod(newPeriod);

        assertEq(escrow.intentExpirationPeriod(), newPeriod);
    }

    function test_setIntentExpirationPeriod_RevertNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        escrow.setIntentExpirationPeriod(1 days);
    }

    function test_setIntentExpirationPeriod_RevertZeroPeriod() public {
        vm.prank(owner);
        vm.expectRevert("Max intent expiration period cannot be zero");
        escrow.setIntentExpirationPeriod(0);
    }

    function test_pause_Success() public {
        assertFalse(escrow.paused());

        vm.prank(owner);
        escrow.pause();

        assertTrue(escrow.paused());
    }

    function test_pause_RevertNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        escrow.pause();
    }

    function test_unpause_Success() public {
        // First pause
        vm.prank(owner);
        escrow.pause();
        assertTrue(escrow.paused());

        // Then unpause
        vm.prank(owner);
        escrow.unpause();

        assertFalse(escrow.paused());
    }

    function test_unpause_RevertNonOwner() public {
        // First pause as owner
        vm.prank(owner);
        escrow.pause();

        // Try to unpause as non-owner
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        escrow.unpause();
    }

    // ============ withdrawDeposit Tests ============

    function test_withdrawDeposit_CannotWithdrawMoreThanAvailable() public {
        // Create a deposit with 1000 USDT
        uint256 depositAmount = 1000e6;
        uint256 depositId = _createDeposit(alice, depositAmount, 100e6, 500e6);

        // Create an intent to lock some funds
        uint256 intentAmount = 300e6;
        vm.prank(bob);
        escrow.signalIntent(depositId, intentAmount, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Check balances before withdrawal
        uint256 aliceBalanceBefore = usdt.balanceOf(alice);
        uint256 escrowBalanceBefore = usdt.balanceOf(address(escrow));

        // Get deposit state - public mapping returns all fields except arrays
        (
            address depositor,
            IERC20 token,
            uint256 amount,
            IEscrow.Range memory range,
            bool acceptingIntents,
            uint256 remainingDeposits,
            uint256 outstandingIntentAmount
        ) = escrow.deposits(depositId);

        // Alice can only withdraw remainingDeposits (700 USDT) since 300 USDT is locked in intent
        assertEq(remainingDeposits, depositAmount - intentAmount, "Remaining deposits should be 700 USDT");
        assertEq(outstandingIntentAmount, intentAmount, "Outstanding intent amount should be 300 USDT");

        // Withdraw deposit - this withdraws only what's available (remaining + expired intents)
        vm.prank(alice);
        escrow.withdrawDeposit(depositId);

        // Verify correct amount was withdrawn (only remainingDeposits since intent hasn't expired)
        uint256 aliceBalanceAfter = usdt.balanceOf(alice);
        uint256 escrowBalanceAfter = usdt.balanceOf(address(escrow));

        assertEq(
            aliceBalanceAfter - aliceBalanceBefore, remainingDeposits, "Alice should receive only remaining deposits"
        );
        assertEq(
            escrowBalanceBefore - escrowBalanceAfter,
            remainingDeposits,
            "Escrow should transfer only remaining deposits"
        );

        // Verify deposit still exists with outstanding intent
        (depositor,,,,,, outstandingIntentAmount) = escrow.deposits(depositId);
        assertEq(depositor, alice, "Deposit should still exist");
        assertEq(outstandingIntentAmount, intentAmount, "Outstanding intent amount should remain");
    }
}

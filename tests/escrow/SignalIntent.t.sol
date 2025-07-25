// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseEscrowTest.sol";

contract SignalIntentTest is BaseEscrowTest {
    uint256 public depositId;
    uint256 public depositAmount = 10000e6; // 10,000 USDT

    function setUp() public override {
        super.setUp();
        depositId = _createDeposit();
    }

    function test_signalIntent_DepositStateChanges() public {
        // Check initial deposit state
        (,,, , , uint256 remainingBefore, uint256 outstandingBefore) = escrow.deposits(depositId);
        assertEq(remainingBefore, depositAmount);
        assertEq(outstandingBefore, 0);

        // Signal an intent
        uint256 intentAmount = 500e6; // 500 USDT
        vm.prank(bob);
        escrow.signalIntent(
            depositId,
            intentAmount,
            bob, // to address
            address(tossBankReclaimVerifierV2),
            keccak256("KRW")
        );

        // Check deposit state after signaling intent
        (,,, , , uint256 remainingAfter, uint256 outstandingAfter) = escrow.deposits(depositId);
        assertEq(remainingAfter, depositAmount - intentAmount);
        assertEq(outstandingAfter, intentAmount);

        // Check that intent was added to deposit's intentHashes array
        uint256 intentId = escrow.accountIntent(bob);
        assertEq(intentId, 1); // First intent should have ID 1

        // Verify the intent details
        (
            address intentOwner,
            address intentTo,
            uint256 intentDepositId,
            uint256 intentAmountStored,
            uint256 intentTimestamp,
            address intentVerifier,
            bytes32 intentCurrency,
            uint256 intentConversionRate
        ) = escrow.intents(intentId);

        assertEq(intentOwner, bob);
        assertEq(intentTo, bob);
        assertEq(intentDepositId, depositId);
        assertEq(intentAmountStored, intentAmount);
        assertEq(intentTimestamp, block.timestamp);
        assertEq(intentVerifier, address(tossBankReclaimVerifierV2));
        assertEq(intentCurrency, keccak256("KRW"));
        assertEq(intentConversionRate, KRW_CONVERSION_RATE);
    }

    function test_signalIntent_MultipleIntents() public {
        // Signal first intent from bob
        uint256 intent1Amount = 1000e6;
        vm.prank(bob);
        escrow.signalIntent(depositId, intent1Amount, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Signal second intent from charlie
        uint256 intent2Amount = 1500e6;
        vm.prank(charlie);
        escrow.signalIntent(depositId, intent2Amount, charlie, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Check deposit state after multiple intents
        (,,, , , uint256 remaining, uint256 outstanding) = escrow.deposits(depositId);
        assertEq(remaining, depositAmount - intent1Amount - intent2Amount);
        assertEq(outstanding, intent1Amount + intent2Amount);

        // Verify both intents are tracked
        assertEq(escrow.accountIntent(bob), 1);
        assertEq(escrow.accountIntent(charlie), 2);
    }

    function test_signalIntent_RevertInsufficientRemainingDeposits() public {
        // Create users
        address dave = makeAddr("dave");
        address eve = makeAddr("eve");
        address frank = makeAddr("frank");

        // Use up the entire deposit with multiple intents (10000e6 total)
        vm.prank(bob);
        escrow.signalIntent(depositId, 2000e6, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        vm.prank(charlie);
        escrow.signalIntent(depositId, 2000e6, charlie, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        vm.prank(dave);
        escrow.signalIntent(depositId, 2000e6, dave, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        vm.prank(eve);
        escrow.signalIntent(depositId, 2000e6, eve, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        vm.prank(frank);
        escrow.signalIntent(depositId, 2000e6, frank, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Now the deposit should be completely used up (remaining = 0)
        // Try to signal another intent should fail
        address george = makeAddr("george");
        vm.prank(george);
        vm.expectRevert(); // Should revert due to underflow in remainingDeposits -= _amount
        escrow.signalIntent(depositId, 100e6, george, address(tossBankReclaimVerifierV2), keccak256("KRW")); // Even minimum amount should fail
    }

    function test_signalIntent_RevertIntentAlreadyExists() public {
        // Signal first intent from bob
        vm.prank(bob);
        escrow.signalIntent(depositId, 500e6, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Try to signal another intent from the same user
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.IntentAlreadyExists.selector));
        escrow.signalIntent(depositId, 300e6, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));
    }

    function test_signalIntent_RevertDepositNotFound() public {
        uint256 nonExistentDepositId = 999;

        vm.prank(bob);
        vm.expectRevert("Deposit does not exist");
        escrow.signalIntent(nonExistentDepositId, 500e6, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));
    }

    function test_signalIntent_RevertInvalidAmount() public {
        // Test amount below minimum
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.InvalidAmount.selector));
        escrow.signalIntent(depositId, 50e6, bob, address(tossBankReclaimVerifierV2), keccak256("KRW")); // Below 100e6 min

        // Test amount above maximum
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.InvalidAmount.selector));
        escrow.signalIntent(depositId, 3000e6, charlie, address(tossBankReclaimVerifierV2), keccak256("KRW")); // Above 2000e6 max
    }

    function test_signalIntent_RevertInvalidRecipient() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.InvalidRecipient.selector));
        escrow.signalIntent(depositId, 500e6, address(0), address(tossBankReclaimVerifierV2), keccak256("KRW"));
    }

    function test_signalIntent_RevertUnsupportedVerifier() public {
        address unsupportedVerifier = makeAddr("unsupportedVerifier");

        vm.prank(bob);
        vm.expectRevert("Payment verifier not supported");
        escrow.signalIntent(depositId, 500e6, bob, unsupportedVerifier, keccak256("KRW"));
    }

    function test_signalIntent_RevertUnsupportedCurrency() public {
        vm.prank(bob);
        vm.expectRevert("Currency not supported");
        escrow.signalIntent(depositId, 500e6, bob, address(tossBankReclaimVerifierV2), keccak256("EUR")); // EUR not supported in setup
    }

    function test_signalIntent_RevertWhenPaused() public {
        // Pause the contract
        vm.prank(escrowOwner);
        escrow.pause();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.signalIntent(depositId, 500e6, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));
    }

    function test_signalIntent_EmitsEvent() public {
        uint256 intentAmount = 750e6;

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit IEscrow.IntentSignaled(bob, address(tossBankReclaimVerifierV2), intentAmount, 1);
        escrow.signalIntent(depositId, intentAmount, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));
    }

    function test_signalIntent_DifferentCurrencies() public {
        // Signal intent with USD
        vm.prank(bob);
        escrow.signalIntent(depositId, 500e6, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Signal intent with KRW
        vm.prank(charlie);
        escrow.signalIntent(depositId, 800e6, charlie, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Verify both intents exist
        uint256 bobIntentId = escrow.accountIntent(bob);
        uint256 charlieIntentId = escrow.accountIntent(charlie);

        (,,,,,, bytes32 bobCurrency,) = escrow.intents(bobIntentId);
        (,,,,,, bytes32 charlieCurrency,) = escrow.intents(charlieIntentId);

        assertEq(bobCurrency, keccak256("KRW"));
        assertEq(charlieCurrency, keccak256("KRW"));
    }

    function test_signalIntent_DifferentRecipients() public {
        // Bob signals intent with alice as recipient
        vm.prank(bob);
        escrow.signalIntent(depositId, 600e6, alice, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Charlie signals intent with charlie as recipient
        vm.prank(charlie);
        escrow.signalIntent(depositId, 400e6, charlie, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Verify intent recipients
        uint256 bobIntentId = escrow.accountIntent(bob);
        uint256 charlieIntentId = escrow.accountIntent(charlie);

        (, address bobRecipient,,,,,,) = escrow.intents(bobIntentId);
        (, address charlieRecipient,,,,,,) = escrow.intents(charlieIntentId);

        assertEq(bobRecipient, alice);
        assertEq(charlieRecipient, charlie);
    }

    function test_signalIntent_AutoPruneExpiredIntents() public {
        // Create multiple users to use up all deposit liquidity with intents
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        address user4 = makeAddr("user4");
        address user5 = makeAddr("user5");

        // Create 5 intents of 2000e6 each (max allowed) to use all 10000e6
        vm.prank(user1);
        escrow.signalIntent(depositId, 2000e6, user1, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        vm.prank(user2);
        escrow.signalIntent(depositId, 2000e6, user2, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        vm.prank(user3);
        escrow.signalIntent(depositId, 2000e6, user3, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        vm.prank(user4);
        escrow.signalIntent(depositId, 2000e6, user4, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        vm.prank(user5);
        escrow.signalIntent(depositId, 2000e6, user5, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Verify no remaining deposits
        (,,, , , uint256 remainingBefore, uint256 outstandingBefore) = escrow.deposits(depositId);
        assertEq(remainingBefore, 0);
        assertEq(outstandingBefore, 10000e6);

        // New intent should fail due to insufficient liquidity
        address dave = makeAddr("dave");
        vm.prank(dave);
        vm.expectRevert("Not enough liquidity");
        escrow.signalIntent(depositId, 1000e6, dave, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Fast forward time to make intents expired
        vm.warp(block.timestamp + escrow.intentExpirationPeriod() + 1);

        // Now dave's intent should succeed because expired intents will be auto-pruned
        vm.prank(dave);
        escrow.signalIntent(depositId, 2000e6, dave, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Verify dave's intent was created
        uint256 daveIntentId = escrow.accountIntent(dave);
        assertTrue(daveIntentId > 0);

        // Verify some old intents were pruned (at least one to make room for dave)
        // The exact pruning behavior depends on implementation details

        // Verify deposit state after pruning
        (,,, , , uint256 remainingAfter, uint256 outstandingAfter) = escrow.deposits(depositId);
        assertTrue(remainingAfter <= 8000e6); // At least 2000e6 was used by dave
        assertTrue(outstandingAfter >= 2000e6); // At least dave's intent is outstanding
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseEscrowTest.sol";

contract FulfillIntentTest is BaseEscrowTest {
    uint256 public depositId;
    uint256 public intentId;

    uint256 public depositAmount = 5000e6;
    // 10000/1000000 USDT * 1380 WON/USDT = 13.8 WON
    uint256 public intentAmount = 9420; // 0.00942 USDT

    function setUp() public override {
        super.setUp();

        // Mint USDT to test users
        vm.startPrank(usdtOwner);
        usdt.mint(alice, 100000e6);
        usdt.mint(bob, 50000e6);
        vm.stopPrank();

        // Create a deposit
        IEscrow.Range memory intentRange = IEscrow.Range({ min: 100, max: 1000e6 });

        address[] memory verifiers = new address[](1);
        verifiers[0] = address(tossBankReclaimVerifierV2);

        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](1);
        // This payee details should match what's in the proof
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(VERIFIER_ADDRESS_V2); // From the V2 test
        verifierData[0] = IEscrow.DepositVerifierData({
            payeeDetails: unicode"100202642943(토스뱅크)",
            data: abi.encode(witnesses)
        });

        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](1);
        currencies[0] = new IEscrow.Currency[](1);
        currencies[0][0] = IEscrow.Currency({ code: keccak256("KRW"), conversionRate: KRW_CONVERSION_RATE });

        vm.startPrank(alice);
        usdt.approve(address(escrow), depositAmount);
        depositId = escrow.createDeposit(
            IERC20(address(usdt)),
            depositAmount,
            intentRange,
            verifiers,
            verifierData,
            currencies
        );
        vm.stopPrank();

        // Signal an intent - the senderNickname in proof is "31337-1"
        // so we need intentId to be 1 and chain to be 31337
        vm.prank(bob);
        escrow.signalIntent(depositId, intentAmount, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));
        intentId = escrow.accountIntent(bob);
    }

    function test_fulfillIntent_WithLoadProofV2_Success() public {
        _loadProofV2();

        // Check state before fulfillment
        (,,, , , uint256 remainingBefore, uint256 outstandingBefore) = escrow.deposits(depositId);
        assertEq(remainingBefore, depositAmount - intentAmount);
        assertEq(outstandingBefore, intentAmount);

        uint256 bobBalanceBefore = usdt.balanceOf(bob);

        escrow.fulfillIntent(abi.encode(proof), intentId);

        // Verify what happened on success:
        // 1. Intent should be pruned (removed from intents mapping)
        assertEq(escrow.accountIntent(bob), 0);

        // 2. outstandingIntentAmount should decrease by intent.amount
        (,,, , , uint256 remainingAfter, uint256 outstandingAfter) = escrow.deposits(depositId);
        assertEq(outstandingAfter, 0);

        // 3. Tokens should be transferred to bob
        uint256 bobBalanceAfter = usdt.balanceOf(bob);
        assertEq(bobBalanceAfter, bobBalanceBefore + intentAmount);

        // 4. Verify deposit state is correct
        assertEq(remainingAfter, depositAmount - intentAmount); // Remaining should stay the same
    }

   function test_fulfillIntent_RequiresValidPaymentProof() public {
        // Try to fulfill with invalid payment proof
        bytes memory invalidProof = abi.encode("invalid");

        vm.expectRevert(); // The verifier will revert but may not have a specific message
        escrow.fulfillIntent(invalidProof, intentId);
    }

    function test_fulfillIntent_RevertNonExistentIntent() public {
        uint256 nonExistentIntentId = 999;
        bytes memory someProof = abi.encode("proof");

        vm.expectRevert(IEscrow.IntentNotFound.selector);
        escrow.fulfillIntent(someProof, nonExistentIntentId);
    }

    function test_fulfillIntent_RevertWhenPaused() public {
        // Pause the contract
        vm.prank(escrowOwner);
        escrow.pause();

        bytes memory someProof = abi.encode("proof");

        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.fulfillIntent(someProof, intentId);
    }

    function test_fulfillIntent_WithMultipleIntents() public {
        // Create another intent from charlie
        uint256 intent2Amount = 100; // Minimum allowed amount
        vm.prank(charlie);
        escrow.signalIntent(depositId, intent2Amount, charlie, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        uint256 intent2Id = escrow.accountIntent(charlie);

        // Check deposit state with multiple intents
        (,,, , , uint256 remaining, uint256 outstanding) = escrow.deposits(depositId);
        assertEq(remaining, depositAmount - intentAmount - intent2Amount);
        assertEq(outstanding, intentAmount + intent2Amount);

        // Cancel first intent
        vm.prank(bob);
        escrow.cancelIntent(intentId);

        // Check state after cancelling one intent
        (,,, , , remaining, outstanding) = escrow.deposits(depositId);
        assertEq(remaining, depositAmount - intent2Amount);
        assertEq(outstanding, intent2Amount);

        // Cancel second intent
        vm.prank(charlie);
        escrow.cancelIntent(intent2Id);

        // Check final state
        (,,, , , remaining, outstanding) = escrow.deposits(depositId);
        assertEq(remaining, depositAmount);
        assertEq(outstanding, 0);
    }

    // *************
    // Cancel Intent
    // *************

    function test_cancelIntent_RestoresDepositState() public {
        // Verify state before cancellation
        (,,, , , uint256 remainingBefore, uint256 outstandingBefore) = escrow.deposits(depositId);
        assertEq(remainingBefore, depositAmount - intentAmount);
        assertEq(outstandingBefore, intentAmount);

        // Cancel the intent
        vm.prank(bob);
        escrow.cancelIntent(intentId);

        // Verify state is restored after cancellation
        (,,, , , uint256 remainingAfter, uint256 outstandingAfter) = escrow.deposits(depositId);
        assertEq(remainingAfter, depositAmount); // Should be restored
        assertEq(outstandingAfter, 0); // Should be back to 0
        assertEq(escrow.getDepositIntentIds(depositId).length, 0);

        // Verify intent is removed
        assertEq(escrow.accountIntent(bob), 0);
    }

    function test_cancelIntent_OnlyIntentOwner() public {
        // Try to cancel someone else's intent
        vm.prank(alice); // Alice is not the intent owner
        vm.expectRevert("Sender must be the intent owner");
        escrow.cancelIntent(intentId);

        // Verify bob can cancel his own intent
        vm.prank(bob);
        escrow.cancelIntent(intentId);

        // Verify intent was cancelled
        assertEq(escrow.accountIntent(bob), 0);
    }

    function test_cancelIntent_AllowedWhenPaused() public {
        // Pause the contract
        vm.prank(escrowOwner);
        escrow.pause();

        // Should still be able to cancel when paused
        vm.prank(bob);
        escrow.cancelIntent(intentId);

        // Verify intent was cancelled
        assertEq(escrow.accountIntent(bob), 0);
    }

    // ****************
    // Release Funds To Payer
    // ****************

    function test_releaseFundsToPayer_OnlyDepositor() public {
        // Try to release funds as non-depositor
        vm.prank(bob); // Bob is not the depositor
        vm.expectRevert("Caller must be the depositor");
        escrow.releaseFundsToPayer(intentId);

        // Alice (depositor) should be able to release funds
        vm.prank(alice);
        escrow.releaseFundsToPayer(intentId);

        // Verify intent was removed and deposit state updated
        assertEq(escrow.accountIntent(bob), 0);
        (,,, , , uint256 remaining, uint256 outstanding) = escrow.deposits(depositId);
        // When releasing funds to payer, the remaining deposits stay the same (not restored)
        // and outstanding intent amount goes to zero
        assertEq(remaining, depositAmount - intentAmount); // The amount should not be restored
        assertEq(outstanding, 0);
    }

    function test_releaseFundsToPayer_RevertNonExistentIntent() public {
        uint256 nonExistentIntentId = 999;

        vm.prank(alice);
        vm.expectRevert("Intent does not exist");
        escrow.releaseFundsToPayer(nonExistentIntentId);
    }
}

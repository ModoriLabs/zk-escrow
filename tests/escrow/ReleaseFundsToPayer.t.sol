// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseEscrowUpgradeableTest.sol";

contract ReleaseFundsToPayerTest is BaseEscrowUpgradeableTest {
    uint256 public depositId;
    uint256 public intentId;
    uint256 public depositAmount = 5000e6; // 5,000 USDT
    uint256 public intentAmount = 1000e6; // 1,000 USDT

    function setUp() public override {
        super.setUp();

        // Create a deposit and intent
        _setupDepositAndIntent();
    }

    function _setupDepositAndIntent() internal {
        // Create a deposit
        IEscrow.Range memory intentRange = IEscrow.Range({ min: 100e6, max: 2000e6 });

        address[] memory verifiers = new address[](1);
        verifiers[0] = address(tossBankReclaimVerifierV2);

        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](1);
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(VERIFIER_ADDRESS_V2);
        verifierData[0] =
            IEscrow.DepositVerifierData({ payeeDetails: unicode"100202642943(토스뱅크)", data: abi.encode(witnesses) });

        uint256 conversionRate = 1380 * PRECISE_UNIT;
        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](1);
        currencies[0] = new IEscrow.Currency[](1);
        currencies[0][0] = IEscrow.Currency({ code: keccak256("KRW"), conversionRate: conversionRate });

        vm.startPrank(alice);
        usdt.approve(address(escrow), depositAmount);
        depositId =
            escrow.createDeposit(IERC20(address(usdt)), depositAmount, intentRange, verifiers, verifierData, currencies);
        vm.stopPrank();

        // Signal an intent
        vm.prank(bob);
        escrow.signalIntent(depositId, intentAmount, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));
        intentId = escrow.accountIntent(bob);
    }

    function test_releaseFundsToPayer_Success() public {
        // Check initial state
        (,,,,, uint256 remainingBefore, uint256 outstandingBefore) = escrow.deposits(depositId);
        assertEq(remainingBefore, depositAmount - intentAmount);
        assertEq(outstandingBefore, intentAmount);

        uint256 bobBalanceBefore = usdt.balanceOf(bob);
        uint256 escrowBalanceBefore = usdt.balanceOf(address(escrow));

        // Release funds to payer as depositor
        vm.prank(alice);
        escrow.releaseFundsToPayer(intentId);

        // Verify intent was removed
        assertEq(escrow.accountIntent(bob), 0);

        // Verify intent was pruned from deposit's intentIds array
        assertEq(escrow.getDepositIntentIds(depositId).length, 0);

        // Verify deposit state was updated
        (,,,,, uint256 remainingAfter, uint256 outstandingAfter) = escrow.deposits(depositId);
        assertEq(remainingAfter, depositAmount - intentAmount); // Remaining stays the same
        assertEq(outstandingAfter, 0); // Outstanding amount reduced

        // Verify tokens were transferred to intent recipient
        uint256 bobBalanceAfter = usdt.balanceOf(bob);
        uint256 escrowBalanceAfter = usdt.balanceOf(address(escrow));

        assertEq(bobBalanceAfter, bobBalanceBefore + intentAmount);
        assertEq(escrowBalanceAfter, escrowBalanceBefore - intentAmount);
    }

    function test_releaseFundsToPayer_OnlyDepositor() public {
        // Try to release funds as non-depositor (bob)
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.OnlyDepositor.selector));
        escrow.releaseFundsToPayer(intentId);

        // Try to release funds as charlie
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.OnlyDepositor.selector));
        escrow.releaseFundsToPayer(intentId);

        // Alice (depositor) should be able to release funds
        vm.prank(alice);
        escrow.releaseFundsToPayer(intentId);

        // Verify intent was removed
        assertEq(escrow.accountIntent(bob), 0);
    }

    function test_releaseFundsToPayer_RevertNonExistentIntent() public {
        uint256 nonExistentIntentId = 999;

        vm.prank(alice);
        vm.expectRevert(IEscrow.IntentNotFound.selector);
        escrow.releaseFundsToPayer(nonExistentIntentId);
    }

    function test_releaseFundsToPayer_RevertIntentIdZero() public {
        vm.prank(alice);
        vm.expectRevert(IEscrow.IntentNotFound.selector);
        escrow.releaseFundsToPayer(0);
    }

    function test_releaseFundsToPayer_MultipleIntents() public {
        // Create additional intents
        uint256 intent2Amount = 500e6;
        uint256 intent3Amount = 300e6;

        vm.prank(charlie);
        escrow.signalIntent(depositId, intent2Amount, charlie, address(tossBankReclaimVerifierV2), keccak256("KRW"));
        uint256 intent2Id = escrow.accountIntent(charlie);

        vm.prank(bob); // Bob creates another intent (will replace his previous one)
        escrow.cancelIntent(intentId); // Cancel first intent

        vm.prank(bob);
        escrow.signalIntent(depositId, intent3Amount, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));
        uint256 intent3Id = escrow.accountIntent(bob);

        // Check deposit state before releases
        (,,,,, uint256 remainingBefore, uint256 outstandingBefore) = escrow.deposits(depositId);
        assertEq(outstandingBefore, intent2Amount + intent3Amount);

        uint256 charlieBalanceBefore = usdt.balanceOf(charlie);
        uint256 bobBalanceBefore = usdt.balanceOf(bob);

        // Release Charlie's intent
        vm.prank(alice);
        escrow.releaseFundsToPayer(intent2Id);

        // Verify Charlie received funds
        assertEq(usdt.balanceOf(charlie), charlieBalanceBefore + intent2Amount);
        assertEq(escrow.accountIntent(charlie), 0);

        // Check deposit state after first release
        (,,,,,, uint256 outstandingAfterFirst) = escrow.deposits(depositId);
        assertEq(outstandingAfterFirst, intent3Amount);

        // Release Bob's intent
        vm.prank(alice);
        escrow.releaseFundsToPayer(intent3Id);

        // Verify Bob received funds
        assertEq(usdt.balanceOf(bob), bobBalanceBefore + intent3Amount);
        assertEq(escrow.accountIntent(bob), 0);

        // Check final deposit state
        (,,,,,, uint256 outstandingFinal) = escrow.deposits(depositId);
        assertEq(outstandingFinal, 0);
        assertEq(escrow.getDepositIntentIds(depositId).length, 0);
    }

    function test_releaseFundsToPayer_DifferentRecipient() public {
        // Cancel existing intent and create new one with different recipient
        vm.prank(bob);
        escrow.cancelIntent(intentId);

        // Create intent where bob pays but alice receives
        vm.prank(bob);
        escrow.signalIntent(depositId, intentAmount, alice, address(tossBankReclaimVerifierV2), keccak256("KRW"));
        uint256 newIntentId = escrow.accountIntent(bob);

        uint256 aliceBalanceBefore = usdt.balanceOf(alice);
        uint256 bobBalanceBefore = usdt.balanceOf(bob);

        // Release funds - should go to alice (recipient), not bob (intent owner)
        vm.prank(alice); // alice is the depositor
        escrow.releaseFundsToPayer(newIntentId);

        // Verify alice received the funds (she was the recipient)
        assertEq(usdt.balanceOf(alice), aliceBalanceBefore + intentAmount);
        assertEq(usdt.balanceOf(bob), bobBalanceBefore); // Bob balance unchanged
        assertEq(escrow.accountIntent(bob), 0);
    }

    function test_releaseFundsToPayer_AfterIntentCancellation() public {
        // Cancel the intent
        vm.prank(bob);
        escrow.cancelIntent(intentId);

        // Try to release funds for cancelled intent
        vm.prank(alice);
        vm.expectRevert(IEscrow.IntentNotFound.selector);
        escrow.releaseFundsToPayer(intentId);
    }

    function test_releaseFundsToPayer_WithZeroAmount() public {
        // Create a minimal intent (testing edge case)
        uint256 minAmount = 100e6; // Minimum allowed

        vm.prank(charlie);
        escrow.signalIntent(depositId, minAmount, charlie, address(tossBankReclaimVerifierV2), keccak256("KRW"));
        uint256 minIntentId = escrow.accountIntent(charlie);

        uint256 charlieBalanceBefore = usdt.balanceOf(charlie);

        // Release the minimal intent
        vm.prank(alice);
        escrow.releaseFundsToPayer(minIntentId);

        // Verify charlie received the minimal amount
        assertEq(usdt.balanceOf(charlie), charlieBalanceBefore + minAmount);
        assertEq(escrow.accountIntent(charlie), 0);
    }

    function test_releaseFundsToPayer_DepositStateConsistency() public {
        // Create multiple intents to test deposit state consistency
        uint256 intent2Amount = 800e6;

        vm.prank(charlie);
        escrow.signalIntent(depositId, intent2Amount, charlie, address(tossBankReclaimVerifierV2), keccak256("KRW"));
        uint256 intent2Id = escrow.accountIntent(charlie);

        // Check initial state
        (,,,,, uint256 remainingBefore, uint256 outstandingBefore) = escrow.deposits(depositId);
        assertEq(remainingBefore, depositAmount - intentAmount - intent2Amount);
        assertEq(outstandingBefore, intentAmount + intent2Amount);

        // Release first intent
        vm.prank(alice);
        escrow.releaseFundsToPayer(intentId);

        // Check state after first release
        (,,,,, uint256 remainingAfter1, uint256 outstandingAfter1) = escrow.deposits(depositId);
        assertEq(remainingAfter1, depositAmount - intentAmount - intent2Amount); // Remaining unchanged
        assertEq(outstandingAfter1, intent2Amount); // Outstanding reduced by first intent

        // Release second intent
        vm.prank(alice);
        escrow.releaseFundsToPayer(intent2Id);

        // Check final state
        (,,,,, uint256 remainingFinal, uint256 outstandingFinal) = escrow.deposits(depositId);
        assertEq(remainingFinal, depositAmount - intentAmount - intent2Amount); // Remaining still unchanged
        assertEq(outstandingFinal, 0); // All outstanding intents released

        // Verify all intents are pruned
        assertEq(escrow.getDepositIntentIds(depositId).length, 0);
    }

    function test_releaseFundsToPayer_MultipleDeposits() public {
        // Create a second deposit from bob
        uint256 deposit2Amount = 3000e6;

        IEscrow.Range memory intentRange = IEscrow.Range({ min: 100e6, max: 1000e6 });
        address[] memory verifiers = new address[](1);
        verifiers[0] = address(tossBankReclaimVerifierV2);

        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](1);
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(VERIFIER_ADDRESS_V2);
        verifierData[0] =
            IEscrow.DepositVerifierData({ payeeDetails: unicode"100202642943(토스뱅크)", data: abi.encode(witnesses) });

        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](1);
        currencies[0] = new IEscrow.Currency[](1);
        currencies[0][0] = IEscrow.Currency({ code: keccak256("KRW"), conversionRate: 1380 * PRECISE_UNIT });

        vm.startPrank(bob);
        usdt.approve(address(escrow), deposit2Amount);
        uint256 deposit2Id = escrow.createDeposit(
            IERC20(address(usdt)), deposit2Amount, intentRange, verifiers, verifierData, currencies
        );
        vm.stopPrank();

        // Create intent on second deposit
        vm.prank(charlie);
        escrow.signalIntent(deposit2Id, 500e6, charlie, address(tossBankReclaimVerifierV2), keccak256("KRW"));
        uint256 intent2Id = escrow.accountIntent(charlie);

        // Alice can only release from her deposit (deposit1)
        vm.prank(alice);
        escrow.releaseFundsToPayer(intentId); // This should work

        // Alice cannot release from bob's deposit
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.OnlyDepositor.selector));
        escrow.releaseFundsToPayer(intent2Id);

        // Bob can release from his deposit
        vm.prank(bob);
        escrow.releaseFundsToPayer(intent2Id); // This should work

        // Verify both intents were processed correctly
        assertEq(escrow.accountIntent(bob), 0);
        assertEq(escrow.accountIntent(charlie), 0);
    }
}

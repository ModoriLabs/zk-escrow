// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseEscrowTest.sol";

contract UpdateDepositIntentAmountRangeTest is BaseEscrowTest {
    uint256 public depositId;
    uint256 public depositAmount = 10_000e6; // 10,000 USDT
    uint256 public initialMin = 100e6; // 100 USDT
    uint256 public initialMax = 2000e6; // 2000 USDT

    function setUp() public override {
        super.setUp();
        // Create a deposit for testing
        depositId = _createDeposit(alice, depositAmount, initialMin, initialMax);
    }

    function test_updateDepositIntentAmountRange_Success() public {
        uint256 newMin = 50e6; // 50 USDT
        uint256 newMax = 5000e6; // 5000 USDT

        // Get initial range
        (,,,IEscrow.Range memory initialRange,,,) = escrow.deposits(depositId);
        assertEq(initialRange.min, initialMin);
        assertEq(initialRange.max, initialMax);

        // Update range as depositor
        vm.expectEmit(true, false, false, true);
        emit IEscrow.DepositIntentAmountRangeUpdated(
            depositId,
            IEscrow.Range(initialMin, initialMax),
            IEscrow.Range(newMin, newMax)
        );
        
        vm.prank(alice);
        escrow.updateDepositIntentAmountRange(depositId, newMin, newMax);

        // Verify the range was updated
        (,,,IEscrow.Range memory updatedRange,,,) = escrow.deposits(depositId);
        assertEq(updatedRange.min, newMin);
        assertEq(updatedRange.max, newMax);
    }

    function test_updateDepositIntentAmountRange_RevertNotDepositor() public {
        uint256 newMin = 50e6;
        uint256 newMax = 5000e6;

        // Try to update as non-depositor (bob)
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.OnlyDepositor.selector));
        escrow.updateDepositIntentAmountRange(depositId, newMin, newMax);
    }

    function test_updateDepositIntentAmountRange_RevertMinZero() public {
        uint256 newMin = 0;
        uint256 newMax = 5000e6;

        // Try to update with zero min
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.InvalidIntentAmountRange.selector));
        escrow.updateDepositIntentAmountRange(depositId, newMin, newMax);
    }

    function test_updateDepositIntentAmountRange_RevertInvalidRange() public {
        uint256 newMin = 5000e6;
        uint256 newMax = 100e6; // Max less than min

        // Try to update with invalid range
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.InvalidIntentAmountRange.selector));
        escrow.updateDepositIntentAmountRange(depositId, newMin, newMax);
    }

    function test_updateDepositIntentAmountRange_RevertMaxExceedsDeposit() public {
        uint256 newMin = 100e6;
        uint256 newMax = 20_000e6; // Exceeds deposit amount of 10,000

        // Try to update with max exceeding deposit amount
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.InvalidIntentAmountRange.selector));
        escrow.updateDepositIntentAmountRange(depositId, newMin, newMax);
    }

    function test_updateDepositIntentAmountRange_RevertNonExistentDeposit() public {
        uint256 nonExistentDepositId = 999;
        uint256 newMin = 50e6;
        uint256 newMax = 5000e6;

        // Try to update range for non-existent deposit
        // The function checks depositor == msg.sender first, and for non-existent deposits,
        // depositor is address(0), so msg.sender != address(0) fails with "Caller must be the depositor"
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.OnlyDepositor.selector));
        escrow.updateDepositIntentAmountRange(nonExistentDepositId, newMin, newMax);
    }

    function test_updateDepositIntentAmountRange_RevertWhenPaused() public {
        uint256 newMin = 50e6;
        uint256 newMax = 5000e6;

        // Pause the contract
        vm.prank(escrowOwner);
        escrow.pause();

        // Try to update range when paused
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.updateDepositIntentAmountRange(depositId, newMin, newMax);
    }

    function test_updateDepositIntentAmountRange_MultipleUpdates() public {
        uint256 firstMin = 200e6;
        uint256 firstMax = 3000e6;
        uint256 secondMin = 150e6;
        uint256 secondMax = 4000e6;

        // First update
        vm.prank(alice);
        escrow.updateDepositIntentAmountRange(depositId, firstMin, firstMax);

        (,,,IEscrow.Range memory range1,,,) = escrow.deposits(depositId);
        assertEq(range1.min, firstMin);
        assertEq(range1.max, firstMax);

        // Second update
        vm.prank(alice);
        escrow.updateDepositIntentAmountRange(depositId, secondMin, secondMax);

        (,,,IEscrow.Range memory range2,,,) = escrow.deposits(depositId);
        assertEq(range2.min, secondMin);
        assertEq(range2.max, secondMax);
    }

    function test_updateDepositIntentAmountRange_DoesNotAffectExistingIntents() public {
        // Signal an intent with original range
        uint256 intentAmount = 1500e6; // Within initial range
        vm.prank(bob);
        escrow.signalIntent(depositId, intentAmount, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        uint256 intentId = escrow.accountIntent(bob);
        
        // Verify intent was created with the amount
        (,, uint256 originalDepositId, uint256 originalAmount,,,,) = escrow.intents(intentId);
        assertEq(originalDepositId, depositId);
        assertEq(originalAmount, intentAmount);

        // Update range to exclude the intent amount
        uint256 newMin = 50e6;
        uint256 newMax = 1000e6; // Max is now less than intent amount

        vm.prank(alice);
        escrow.updateDepositIntentAmountRange(depositId, newMin, newMax);

        // Verify existing intent is unaffected
        (,, uint256 unchangedDepositId, uint256 unchangedAmount,,,,) = escrow.intents(intentId);
        assertEq(unchangedDepositId, depositId);
        assertEq(unchangedAmount, intentAmount);
    }

    function test_updateDepositIntentAmountRange_AffectsNewIntents() public {
        // Update range
        uint256 newMin = 500e6;
        uint256 newMax = 1500e6;

        vm.prank(alice);
        escrow.updateDepositIntentAmountRange(depositId, newMin, newMax);

        // Try to signal intent below new minimum
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.InvalidAmount.selector));
        escrow.signalIntent(depositId, 300e6, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Try to signal intent above new maximum
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.InvalidAmount.selector));
        escrow.signalIntent(depositId, 2000e6, charlie, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Signal intent within new range - should succeed
        vm.prank(bob);
        escrow.signalIntent(depositId, 1000e6, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));
        
        uint256 intentId = escrow.accountIntent(bob);
        assertGt(intentId, 0);
    }

    function test_updateDepositIntentAmountRange_BoundaryValues() public {
        // Test with minimum possible range
        uint256 newMin = 1;
        uint256 newMax = 1;

        vm.prank(alice);
        escrow.updateDepositIntentAmountRange(depositId, newMin, newMax);

        (,,,IEscrow.Range memory range,,,) = escrow.deposits(depositId);
        assertEq(range.min, newMin);
        assertEq(range.max, newMax);

        // Test with maximum possible range (up to deposit amount)
        newMin = 1;
        newMax = depositAmount;

        vm.prank(alice);
        escrow.updateDepositIntentAmountRange(depositId, newMin, newMax);

        (,,,IEscrow.Range memory range2,,,) = escrow.deposits(depositId);
        assertEq(range2.min, newMin);
        assertEq(range2.max, newMax);
    }
}
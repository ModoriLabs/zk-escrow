// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseEscrowUpgradeableTest.sol";

contract CancelIntentTest is BaseEscrowUpgradeableTest {
    uint256 public depositId;
    uint256 public intentId;

    uint256 public depositAmount = 5000e6;
    // 10000/1000000 USDT * 1380 WON/USDT = 13.8 WON
    uint256 public intentAmount = 9420; // 0.00942 USDT

    function setUp() public override {
        super.setUp();

        // Mint USDT to test users
        vm.startPrank(usdtOwner);
        usdt.mint(alice, 100_000e6);
        usdt.mint(bob, 50_000e6);
        vm.stopPrank();

        // Create a deposit
        IEscrow.Range memory intentRange = IEscrow.Range({ min: 100, max: 1000e6 });

        address[] memory verifiers = new address[](1);
        verifiers[0] = address(tossBankReclaimVerifierV2);

        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](1);
        // This payee details should match what's in the proof
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(VERIFIER_ADDRESS_V2);
        verifierData[0] = IEscrow.DepositVerifierData({ 
            payeeDetails: unicode"100202642943(토스뱅크)", 
            data: abi.encode(witnesses) 
        });

        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](1);
        currencies[0] = new IEscrow.Currency[](1);
        currencies[0][0] = IEscrow.Currency({ code: keccak256("KRW"), conversionRate: KRW_CONVERSION_RATE });

        vm.startPrank(alice);
        usdt.approve(address(escrow), depositAmount);
        depositId = escrow.createDeposit(IERC20(address(usdt)), depositAmount, intentRange, verifiers, verifierData, currencies);
        vm.stopPrank();

        // Signal an intent
        intentId = _signalIntent(bob, depositId, intentAmount, bob);
    }

    function test_cancelIntent_RestoresDepositState() public {
        // Verify state before cancellation
        (,,,,, uint256 remainingBefore, uint256 outstandingBefore) = escrow.deposits(depositId);
        assertEq(remainingBefore, depositAmount - intentAmount);
        assertEq(outstandingBefore, intentAmount);

        // Cancel the intent
        vm.prank(bob);
        escrow.cancelIntent(intentId);

        // Verify state is restored after cancellation
        (,,,,, uint256 remainingAfter, uint256 outstandingAfter) = escrow.deposits(depositId);
        assertEq(remainingAfter, depositAmount); // Should be restored
        assertEq(outstandingAfter, 0); // Should be back to 0
        assertEq(escrow.getDepositIntentIds(depositId).length, 0);

        // Verify intent is removed
        assertEq(escrow.accountIntent(bob), 0);
    }

    function test_cancelIntent_OnlyIntentOwner() public {
        // Try to cancel someone else's intent
        vm.prank(alice); // Alice is not the intent owner
        vm.expectRevert(IEscrow.OnlyIntentOwner.selector);
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
}
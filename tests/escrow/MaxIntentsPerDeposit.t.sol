// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseEscrowTest.sol";

contract MaxIntentsPerDepositTest is BaseEscrowTest {
    uint256 public depositId;
    uint256 public depositAmount = 100_000e6; // 100,000 USDT - large amount for many intents
    uint256 public intentAmount = 100e6; // 100 USDT per intent (minimum)

    function setUp() public override {
        super.setUp();

        // Create many test users for max intents testing
        vm.startPrank(usdtOwner);
        for (uint256 i = 0; i < 150; i++) {
            address user = address(uint160(0x1000 + i));
            usdt.mint(user, 10_000e6);
        }
        vm.stopPrank();

        // Create a large deposit for testing many intents
        depositId = _createDeposit(alice, depositAmount, 100e6, 2000e6);
    }

    function test_maxIntentsPerDeposit_DefaultValue() public {
        assertEq(escrow.maxIntentsPerDeposit(), 100);
    }

    function test_setMaxIntentsPerDeposit_Success() public {
        uint256 newMax = 50;

        vm.prank(escrowOwner);
        vm.expectEmit(false, false, false, true);
        emit IEscrow.MaxIntentsPerDepositUpdated(100, newMax);
        escrow.setMaxIntentsPerDeposit(newMax);

        assertEq(escrow.maxIntentsPerDeposit(), newMax);
    }

    function test_setMaxIntentsPerDeposit_RevertNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(); // Ownable: caller is not the owner
        escrow.setMaxIntentsPerDeposit(50);
    }

    function test_setMaxIntentsPerDeposit_RevertZeroValue() public {
        vm.prank(escrowOwner);
        vm.expectRevert("Max intents must be greater than 0");
        escrow.setMaxIntentsPerDeposit(0);
    }

    function test_signalIntent_ReachMaxIntents() public {
        // Set max intents to a small number for testing
        uint256 maxIntents = 5;
        vm.prank(escrowOwner);
        escrow.setMaxIntentsPerDeposit(maxIntents);

        // Create maximum allowed intents
        for (uint256 i = 0; i < maxIntents; i++) {
            address user = address(uint160(0x1000 + i));
            vm.prank(user);
            escrow.signalIntent(depositId, intentAmount, user, address(tossBankReclaimVerifierV2), keccak256("KRW"));
        }

        // Verify we have max intents
        assertEq(escrow.getDepositIntentIds(depositId).length, maxIntents);

        // Try to create one more intent - should fail
        address extraUser = address(uint160(0x1000 + maxIntents));
        vm.prank(extraUser);
        vm.expectRevert("Maximum intents per deposit reached");
        escrow.signalIntent(depositId, intentAmount, extraUser, address(tossBankReclaimVerifierV2), keccak256("KRW"));
    }

    function test_signalIntent_AllowAfterCancellation() public {
        // Set max intents to a small number
        uint256 maxIntents = 3;
        vm.prank(escrowOwner);
        escrow.setMaxIntentsPerDeposit(maxIntents);

        // Create maximum allowed intents
        address[] memory users = new address[](maxIntents);
        uint256[] memory intentIds = new uint256[](maxIntents);

        for (uint256 i = 0; i < maxIntents; i++) {
            users[i] = address(uint160(0x1000 + i));
            vm.prank(users[i]);
            escrow.signalIntent(depositId, intentAmount, users[i], address(tossBankReclaimVerifierV2), keccak256("KRW"));
            intentIds[i] = escrow.accountIntent(users[i]);
        }

        // Cancel one intent
        vm.prank(users[0]);
        escrow.cancelIntent(intentIds[0]);

        // Should now be able to create a new intent
        address newUser = address(uint160(0x2000));
        vm.prank(newUser);
        escrow.signalIntent(depositId, intentAmount, newUser, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Verify the new intent was created
        assertTrue(escrow.accountIntent(newUser) > 0);
    }

    function test_signalIntent_AllowAfterRelease() public {
        // Set max intents to a small number
        uint256 maxIntents = 3;
        vm.prank(escrowOwner);
        escrow.setMaxIntentsPerDeposit(maxIntents);

        // Create maximum allowed intents
        address[] memory users = new address[](maxIntents);
        uint256[] memory intentIds = new uint256[](maxIntents);

        for (uint256 i = 0; i < maxIntents; i++) {
            users[i] = address(uint160(0x1000 + i));
            vm.prank(users[i]);
            escrow.signalIntent(depositId, intentAmount, users[i], address(tossBankReclaimVerifierV2), keccak256("KRW"));
            intentIds[i] = escrow.accountIntent(users[i]);
        }

        // Release funds for one intent (as depositor)
        vm.prank(alice);
        escrow.releaseFundsToPayer(intentIds[0]);

        // Should now be able to create a new intent
        address newUser = address(uint160(0x2000));
        vm.prank(newUser);
        escrow.signalIntent(depositId, intentAmount, newUser, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Verify the new intent was created
        assertTrue(escrow.accountIntent(newUser) > 0);
    }

    function test_maxIntents_WithPrunableIntents() public {
        // Set max intents to a small number
        uint256 maxIntents = 5;
        vm.prank(escrowOwner);
        escrow.setMaxIntentsPerDeposit(maxIntents);

        // Create maximum allowed intents
        for (uint256 i = 0; i < maxIntents; i++) {
            address user = address(uint160(0x1000 + i));
            vm.prank(user);
            escrow.signalIntent(depositId, intentAmount, user, address(tossBankReclaimVerifierV2), keccak256("KRW"));
        }

        // Fast forward time to make intents prunable
        vm.warp(block.timestamp + escrow.intentExpirationPeriod() + 1);

        // New intent should succeed because expired intents will be pruned
        address newUser = address(uint160(0x2000));
        vm.prank(newUser);
        escrow.signalIntent(depositId, intentAmount, newUser, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Verify new intent was created
        assertTrue(escrow.accountIntent(newUser) > 0);
    }

    function test_maxIntents_MultipleDeposits() public {
        // Set max intents to 2
        vm.prank(escrowOwner);
        escrow.setMaxIntentsPerDeposit(2);

        // Create 2 intents on first deposit
        vm.prank(bob);
        escrow.signalIntent(depositId, intentAmount, bob, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        vm.prank(charlie);
        escrow.signalIntent(depositId, intentAmount, charlie, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Third intent should fail on first deposit
        address dave = makeAddr("dave");
        vm.prank(dave);
        vm.expectRevert("Maximum intents per deposit reached");
        escrow.signalIntent(depositId, intentAmount, dave, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Create a second deposit
        uint256 deposit2Id = _createDeposit();

        // Should be able to create intents on second deposit
        vm.prank(dave);
        escrow.signalIntent(deposit2Id, intentAmount, dave, address(tossBankReclaimVerifierV2), keccak256("KRW"));

        // Verify intent was created on second deposit
        assertTrue(escrow.accountIntent(dave) > 0);
    }

    function test_setMaxIntentsPerDeposit_DoesNotAffectExisting() public {
        // Create 5 intents
        for (uint256 i = 0; i < 5; i++) {
            address user = address(uint160(0x1000 + i));
            vm.prank(user);
            escrow.signalIntent(depositId, intentAmount, user, address(tossBankReclaimVerifierV2), keccak256("KRW"));
        }

        // Reduce max intents to 3
        vm.prank(escrowOwner);
        escrow.setMaxIntentsPerDeposit(3);

        // Existing intents should still be there
        assertEq(escrow.getDepositIntentIds(depositId).length, 5);

        // But cannot create new intents
        address newUser = address(uint160(0x2000));
        vm.prank(newUser);
        vm.expectRevert("Maximum intents per deposit reached");
        escrow.signalIntent(depositId, intentAmount, newUser, address(tossBankReclaimVerifierV2), keccak256("KRW"));
    }
}

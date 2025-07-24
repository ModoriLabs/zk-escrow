// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseTest.sol";
import { Escrow } from "../../src/Escrow.sol";
import { IEscrow } from "../../src/interfaces/IEscrow.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MaxIntentsPerDepositTest is BaseTest {
    address public escrowOwner;
    address public usdtOwner;

    uint256 public depositId;
    uint256 public depositAmount = 100000e6; // 100,000 USDT - large amount for many intents
    uint256 public intentAmount = 100e6; // 100 USDT per intent (minimum)

    function setUp() public override {
        super.setUp();

        escrowOwner = escrow.owner();
        usdtOwner = usdt.owner();

        // Mint USDT to test users
        vm.startPrank(usdtOwner);
        usdt.mint(alice, 1000000e6); // 1M USDT
        // Create many test users
        for (uint i = 0; i < 150; i++) {
            address user = address(uint160(0x1000 + i));
            usdt.mint(user, 10000e6);
        }
        vm.stopPrank();

        // Whitelist the verifier
        vm.prank(escrowOwner);
        escrow.addWhitelistedPaymentVerifier(address(tossBankReclaimVerifier));

        // Create a deposit with wide intent range to allow many intents
        depositId = _createDeposit();
    }

    function _createDeposit() internal returns (uint256) {
        IEscrow.Range memory intentRange = IEscrow.Range({
            min: intentAmount, // 100 USDT minimum
            max: 1000e6 // 1000 USDT maximum
        });

        address[] memory verifiers = new address[](1);
        verifiers[0] = address(tossBankReclaimVerifier);

        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](1);
        verifierData[0] = IEscrow.DepositVerifierData({
            payeeDetails: "test-payee",
            data: abi.encode("test")
        });

        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](1);
        currencies[0] = new IEscrow.Currency[](1);
        currencies[0][0] = IEscrow.Currency({ code: keccak256("USD"), conversionRate: 1e18 });

        vm.startPrank(alice);
        usdt.approve(address(escrow), depositAmount);
        uint256 newDepositId = escrow.createDeposit(
            IERC20(address(usdt)),
            depositAmount,
            intentRange,
            verifiers,
            verifierData,
            currencies
        );
        vm.stopPrank();

        return newDepositId;
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
        for (uint i = 0; i < maxIntents; i++) {
            address user = address(uint160(0x1000 + i));
            vm.prank(user);
            escrow.signalIntent(
                depositId,
                intentAmount,
                user,
                address(tossBankReclaimVerifier),
                keccak256("USD")
            );
        }

        // Verify we have max intents
        assertEq(escrow.getDepositIntentIds(depositId).length, maxIntents);

        // Try to create one more intent - should fail
        address extraUser = address(uint160(0x1000 + maxIntents));
        vm.prank(extraUser);
        vm.expectRevert("Maximum intents per deposit reached");
        escrow.signalIntent(
            depositId,
            intentAmount,
            extraUser,
            address(tossBankReclaimVerifier),
            keccak256("USD")
        );
    }

    function test_signalIntent_AllowAfterCancellation() public {
        // Set max intents to a small number
        uint256 maxIntents = 3;
        vm.prank(escrowOwner);
        escrow.setMaxIntentsPerDeposit(maxIntents);

        // Create maximum allowed intents
        address[] memory users = new address[](maxIntents);
        uint256[] memory intentIds = new uint256[](maxIntents);

        for (uint i = 0; i < maxIntents; i++) {
            users[i] = address(uint160(0x1000 + i));
            vm.prank(users[i]);
            escrow.signalIntent(
                depositId,
                intentAmount,
                users[i],
                address(tossBankReclaimVerifier),
                keccak256("USD")
            );
            intentIds[i] = escrow.accountIntent(users[i]);
        }

        // Cancel one intent
        vm.prank(users[0]);
        escrow.cancelIntent(intentIds[0]);

        // Should now be able to create a new intent
        address newUser = address(uint160(0x2000));
        vm.prank(newUser);
        escrow.signalIntent(
            depositId,
            intentAmount,
            newUser,
            address(tossBankReclaimVerifier),
            keccak256("USD")
        );

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

        for (uint i = 0; i < maxIntents; i++) {
            users[i] = address(uint160(0x1000 + i));
            vm.prank(users[i]);
            escrow.signalIntent(
                depositId,
                intentAmount,
                users[i],
                address(tossBankReclaimVerifier),
                keccak256("USD")
            );
            intentIds[i] = escrow.accountIntent(users[i]);
        }

        // Release funds for one intent (as depositor)
        vm.prank(alice);
        escrow.releaseFundsToPayer(intentIds[0]);

        // Should now be able to create a new intent
        address newUser = address(uint160(0x2000));
        vm.prank(newUser);
        escrow.signalIntent(
            depositId,
            intentAmount,
            newUser,
            address(tossBankReclaimVerifier),
            keccak256("USD")
        );

        // Verify the new intent was created
        assertTrue(escrow.accountIntent(newUser) > 0);
    }

    function test_maxIntents_WithPrunableIntents() public {
        // Set max intents to a small number
        uint256 maxIntents = 5;
        vm.prank(escrowOwner);
        escrow.setMaxIntentsPerDeposit(maxIntents);

        // Create maximum allowed intents
        for (uint i = 0; i < maxIntents; i++) {
            address user = address(uint160(0x1000 + i));
            vm.prank(user);
            escrow.signalIntent(
                depositId,
                intentAmount,
                user,
                address(tossBankReclaimVerifier),
                keccak256("USD")
            );
        }

        // Fast forward time to make intents prunable
        vm.warp(block.timestamp + escrow.intentExpirationPeriod() + 1);

        // New intent should succeed because expired intents will be pruned
        address newUser = address(uint160(0x2000));
        vm.prank(newUser);
        escrow.signalIntent(
            depositId,
            intentAmount,
            newUser,
            address(tossBankReclaimVerifier),
            keccak256("USD")
        );

        // Verify new intent was created
        assertTrue(escrow.accountIntent(newUser) > 0);
    }

    function test_maxIntents_MultipleDeposits() public {
        // Set max intents to 2
        vm.prank(escrowOwner);
        escrow.setMaxIntentsPerDeposit(2);

        // Create 2 intents on first deposit
        vm.prank(bob);
        escrow.signalIntent(depositId, intentAmount, bob, address(tossBankReclaimVerifier), keccak256("USD"));

        vm.prank(charlie);
        escrow.signalIntent(depositId, intentAmount, charlie, address(tossBankReclaimVerifier), keccak256("USD"));

        // Third intent should fail on first deposit
        address dave = makeAddr("dave");
        vm.prank(dave);
        vm.expectRevert("Maximum intents per deposit reached");
        escrow.signalIntent(depositId, intentAmount, dave, address(tossBankReclaimVerifier), keccak256("USD"));

        // Create a second deposit
        uint256 deposit2Id = _createDeposit();

        // Should be able to create intents on second deposit
        vm.prank(dave);
        escrow.signalIntent(deposit2Id, intentAmount, dave, address(tossBankReclaimVerifier), keccak256("USD"));

        // Verify intent was created on second deposit
        assertTrue(escrow.accountIntent(dave) > 0);
    }

    function test_setMaxIntentsPerDeposit_DoesNotAffectExisting() public {
        // Create 5 intents
        for (uint i = 0; i < 5; i++) {
            address user = address(uint160(0x1000 + i));
            vm.prank(user);
            escrow.signalIntent(
                depositId,
                intentAmount,
                user,
                address(tossBankReclaimVerifier),
                keccak256("USD")
            );
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
        escrow.signalIntent(
            depositId,
            intentAmount,
            newUser,
            address(tossBankReclaimVerifier),
            keccak256("USD")
        );
    }
}

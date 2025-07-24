// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseTest.sol";
import { Escrow } from "../../src/Escrow.sol";
import { IEscrow } from "../../src/interfaces/IEscrow.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SignalIntentTest is BaseTest {
    address public escrowOwner;
    address public usdtOwner;

    uint256 public depositId;
    uint256 public depositAmount = 10000e6; // 10,000 USDT

    function setUp() public override {
        super.setUp();

        escrowOwner = escrow.owner();
        usdtOwner = usdt.owner();

        // Mint USDT to test users
        vm.startPrank(usdtOwner);
        usdt.mint(alice, 100000e6);
        usdt.mint(bob, 50000e6);
        usdt.mint(charlie, 30000e6);
        vm.stopPrank();

        // Whitelist the verifier
        vm.prank(escrowOwner);
        escrow.addWhitelistedPaymentVerifier(address(tossBankReclaimVerifier));

        // Create a deposit for testing signalIntent
        IEscrow.Range memory intentRange = IEscrow.Range({
            min: 100e6,
            max: 2000e6
        });

        address[] memory verifiers = new address[](1);
        verifiers[0] = address(tossBankReclaimVerifier);

        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](1);
        verifierData[0] = IEscrow.DepositVerifierData({
            payeeDetails: "test-payee",
            data: abi.encode("test")
        });

        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](1);
        currencies[0] = new IEscrow.Currency[](2);
        currencies[0][0] = IEscrow.Currency({ code: keccak256("USD"), conversionRate: 1e18 });
        currencies[0][1] = IEscrow.Currency({ code: keccak256("KRW"), conversionRate: 1e18 });

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
            address(tossBankReclaimVerifier),
            keccak256("USD")
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
        assertEq(intentVerifier, address(tossBankReclaimVerifier));
        assertEq(intentCurrency, keccak256("USD"));
        assertEq(intentConversionRate, 1e18);
    }

    function test_signalIntent_MultipleIntents() public {
        // Signal first intent from bob
        uint256 intent1Amount = 1000e6;
        vm.prank(bob);
        escrow.signalIntent(depositId, intent1Amount, bob, address(tossBankReclaimVerifier), keccak256("KRW"));

        // Signal second intent from charlie
        uint256 intent2Amount = 1500e6;
        vm.prank(charlie);
        escrow.signalIntent(depositId, intent2Amount, charlie, address(tossBankReclaimVerifier), keccak256("KRW"));

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
        escrow.signalIntent(depositId, 2000e6, bob, address(tossBankReclaimVerifier), keccak256("USD"));

        vm.prank(charlie);
        escrow.signalIntent(depositId, 2000e6, charlie, address(tossBankReclaimVerifier), keccak256("USD"));

        vm.prank(dave);
        escrow.signalIntent(depositId, 2000e6, dave, address(tossBankReclaimVerifier), keccak256("USD"));

        vm.prank(eve);
        escrow.signalIntent(depositId, 2000e6, eve, address(tossBankReclaimVerifier), keccak256("USD"));

        vm.prank(frank);
        escrow.signalIntent(depositId, 2000e6, frank, address(tossBankReclaimVerifier), keccak256("USD"));

        // Now the deposit should be completely used up (remaining = 0)
        // Try to signal another intent should fail
        address george = makeAddr("george");
        vm.prank(george);
        vm.expectRevert(); // Should revert due to underflow in remainingDeposits -= _amount
        escrow.signalIntent(depositId, 100e6, george, address(tossBankReclaimVerifier), keccak256("USD")); // Even minimum amount should fail
    }

    function test_signalIntent_RevertIntentAlreadyExists() public {
        // Signal first intent from bob
        vm.prank(bob);
        escrow.signalIntent(depositId, 500e6, bob, address(tossBankReclaimVerifier), keccak256("USD"));

        // Try to signal another intent from the same user
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.IntentAlreadyExists.selector));
        escrow.signalIntent(depositId, 300e6, bob, address(tossBankReclaimVerifier), keccak256("USD"));
    }

    function test_signalIntent_RevertDepositNotFound() public {
        uint256 nonExistentDepositId = 999;

        vm.prank(bob);
        vm.expectRevert("Deposit does not exist");
        escrow.signalIntent(nonExistentDepositId, 500e6, bob, address(tossBankReclaimVerifier), keccak256("USD"));
    }

    function test_signalIntent_RevertInvalidAmount() public {
        // Test amount below minimum
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.InvalidAmount.selector));
        escrow.signalIntent(depositId, 50e6, bob, address(tossBankReclaimVerifier), keccak256("USD")); // Below 100e6 min

        // Test amount above maximum
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.InvalidAmount.selector));
        escrow.signalIntent(depositId, 3000e6, charlie, address(tossBankReclaimVerifier), keccak256("USD")); // Above 2000e6 max
    }

    function test_signalIntent_RevertInvalidRecipient() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.InvalidRecipient.selector));
        escrow.signalIntent(depositId, 500e6, address(0), address(tossBankReclaimVerifier), keccak256("USD"));
    }

    function test_signalIntent_RevertUnsupportedVerifier() public {
        address unsupportedVerifier = makeAddr("unsupportedVerifier");

        vm.prank(bob);
        vm.expectRevert("Payment verifier not supported");
        escrow.signalIntent(depositId, 500e6, bob, unsupportedVerifier, keccak256("USD"));
    }

    function test_signalIntent_RevertUnsupportedCurrency() public {
        vm.prank(bob);
        vm.expectRevert("Currency not supported");
        escrow.signalIntent(depositId, 500e6, bob, address(tossBankReclaimVerifier), keccak256("EUR")); // EUR not supported in setup
    }

    function test_signalIntent_RevertWhenPaused() public {
        // Pause the contract
        vm.prank(escrowOwner);
        escrow.pause();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.signalIntent(depositId, 500e6, bob, address(tossBankReclaimVerifier), keccak256("USD"));
    }

    function test_signalIntent_EmitsEvent() public {
        uint256 intentAmount = 750e6;

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit IEscrow.IntentSignaled(bob, address(tossBankReclaimVerifier), intentAmount, 1);
        escrow.signalIntent(depositId, intentAmount, bob, address(tossBankReclaimVerifier), keccak256("USD"));
    }

    function test_signalIntent_DifferentCurrencies() public {
        // Signal intent with USD
        vm.prank(bob);
        escrow.signalIntent(depositId, 500e6, bob, address(tossBankReclaimVerifier), keccak256("USD"));

        // Signal intent with KRW
        vm.prank(charlie);
        escrow.signalIntent(depositId, 800e6, charlie, address(tossBankReclaimVerifier), keccak256("KRW"));

        // Verify both intents exist
        uint256 bobIntentId = escrow.accountIntent(bob);
        uint256 charlieIntentId = escrow.accountIntent(charlie);

        (,,,,,, bytes32 bobCurrency,) = escrow.intents(bobIntentId);
        (,,,,,, bytes32 charlieCurrency,) = escrow.intents(charlieIntentId);

        assertEq(bobCurrency, keccak256("USD"));
        assertEq(charlieCurrency, keccak256("KRW"));
    }

    function test_signalIntent_DifferentRecipients() public {
        // Bob signals intent with alice as recipient
        vm.prank(bob);
        escrow.signalIntent(depositId, 600e6, alice, address(tossBankReclaimVerifier), keccak256("USD"));

        // Charlie signals intent with charlie as recipient
        vm.prank(charlie);
        escrow.signalIntent(depositId, 400e6, charlie, address(tossBankReclaimVerifier), keccak256("USD"));

        // Verify intent recipients
        uint256 bobIntentId = escrow.accountIntent(bob);
        uint256 charlieIntentId = escrow.accountIntent(charlie);

        (, address bobRecipient,,,,,,) = escrow.intents(bobIntentId);
        (, address charlieRecipient,,,,,,) = escrow.intents(charlieIntentId);

        assertEq(bobRecipient, alice);
        assertEq(charlieRecipient, charlie);
    }
}

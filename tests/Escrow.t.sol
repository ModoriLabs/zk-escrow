// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./BaseTest.sol";
import { Escrow } from "../src/Escrow.sol";
import { IEscrow } from "../src/interfaces/IEscrow.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract EscrowTest is BaseTest {
    address public escrowOwner;
    address public usdtOwner;

    function setUp() public override {
        super.setUp();

        escrowOwner = escrow.owner();
        usdtOwner = usdt.owner();

        vm.startPrank(usdtOwner);
        usdt.mint(alice, 100000e6); // 100,000 USDT
        usdt.mint(bob, 50000e6);    // 50,000 USDT
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

    function test_pauseUnpause_Integration() public {
        // Setup deposit data
        uint256 depositAmount = 1000e6;
        IEscrow.Range memory intentRange = IEscrow.Range({ min: 100e6, max: 500e6 });

        address[] memory verifiers = new address[](1);
        verifiers[0] = address(tossBankReclaimVerifier);

        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](1);
        verifierData[0] = IEscrow.DepositVerifierData({
            payeeDetails: "test",
            data: abi.encode("test")
        });

        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](1);
        currencies[0] = new IEscrow.Currency[](1);
        currencies[0][0] = IEscrow.Currency({ code: keccak256("USD"), conversionRate: 1e18 });

        // Should work when not paused
        vm.startPrank(alice);
        usdt.approve(address(escrow), depositAmount);
        escrow.createDeposit(
            IERC20(address(usdt)),
            depositAmount,
            intentRange,
            verifiers,
            verifierData,
            currencies
        );
        vm.stopPrank();

        // Pause contract
        vm.prank(owner);
        escrow.pause();

        // Should fail when paused
        vm.startPrank(bob);
        usdt.approve(address(escrow), depositAmount);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.createDeposit(
            IERC20(address(usdt)),
            depositAmount,
            intentRange,
            verifiers,
            verifierData,
            currencies
        );
        vm.stopPrank();

        // Unpause contract
        vm.prank(owner);
        escrow.unpause();

        // Should work again after unpause
        vm.startPrank(bob);
        escrow.createDeposit(
            IERC20(address(usdt)),
            depositAmount,
            intentRange,
            verifiers,
            verifierData,
            currencies
        );
        vm.stopPrank();
    }

    function test_transferOwnership_Success() public {
        address newOwner = makeAddr("newOwner");

        // Current owner is 'owner'
        assertEq(escrow.owner(), owner);

        // Transfer ownership
        vm.prank(owner);
        escrow.transferOwnership(newOwner);

        // New owner should be set
        assertEq(escrow.owner(), newOwner);

        // Old owner should not be able to call onlyOwner functions
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", owner));
        escrow.pause();

        // New owner should be able to call onlyOwner functions
        vm.prank(newOwner);
        escrow.pause();
        assertTrue(escrow.paused());
    }

    function test_renounceOwnership_Success() public {
        // Current owner is 'owner'
        assertEq(escrow.owner(), owner);

        // Renounce ownership
        vm.prank(owner);
        escrow.renounceOwnership();

        // Owner should be zero address
        assertEq(escrow.owner(), address(0));

        // No one should be able to call onlyOwner functions
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", owner));
        escrow.pause();
    }
}

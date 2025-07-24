// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseTest.sol";
import { Escrow } from "../../src/Escrow.sol";
import { IEscrow } from "../../src/interfaces/IEscrow.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UpdateDepositConversionRateTest is BaseTest {
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
        vm.stopPrank();

        // Whitelist the verifier
        vm.prank(escrowOwner);
        escrow.addWhitelistedPaymentVerifier(address(tossBankReclaimVerifier));

        // Create a deposit for testing
        depositId = _createDeposit();
    }

    function _createDeposit() internal returns (uint256) {
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
        currencies[0][1] = IEscrow.Currency({ code: keccak256("KRW"), conversionRate: 1380e18 });

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

    function test_updateDepositConversionRate_Success() public {
        uint256 oldRate = escrow.depositCurrencyConversionRate(
            depositId, 
            address(tossBankReclaimVerifier), 
            keccak256("USD")
        );
        uint256 newRate = 2e18; // New rate: 2.0

        assertEq(oldRate, 1e18); // Initial rate should be 1.0

        // Update conversion rate as depositor
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit IEscrow.DepositConversionRateUpdated(
            depositId, 
            address(tossBankReclaimVerifier), 
            keccak256("USD"), 
            newRate
        );
        
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifier),
            keccak256("USD"),
            newRate
        );

        // Verify the rate was updated
        uint256 updatedRate = escrow.depositCurrencyConversionRate(
            depositId, 
            address(tossBankReclaimVerifier), 
            keccak256("USD")
        );
        assertEq(updatedRate, newRate);
    }

    function test_updateDepositConversionRate_UpdateKRWRate() public {
        uint256 oldKrwRate = escrow.depositCurrencyConversionRate(
            depositId, 
            address(tossBankReclaimVerifier), 
            keccak256("KRW")
        );
        uint256 newKrwRate = 1400e18; // New KRW rate: 1400

        assertEq(oldKrwRate, 1380e18); // Initial KRW rate should be 1380

        // Update KRW conversion rate as depositor
        vm.prank(alice);
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifier),
            keccak256("KRW"),
            newKrwRate
        );

        // Verify the KRW rate was updated
        uint256 updatedKrwRate = escrow.depositCurrencyConversionRate(
            depositId, 
            address(tossBankReclaimVerifier), 
            keccak256("KRW")
        );
        assertEq(updatedKrwRate, newKrwRate);
    }

    function test_updateDepositConversionRate_RevertNotDepositor() public {
        uint256 newRate = 2e18;

        // Try to update as non-depositor (bob)
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.OnlyDepositor.selector));
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifier),
            keccak256("USD"),
            newRate
        );
    }

    function test_updateDepositConversionRate_RevertUnsupportedCurrency() public {
        uint256 newRate = 2e18;

        // Try to update rate for unsupported currency (EUR)
        vm.prank(alice);
        vm.expectRevert("Currency or verifier not supported");
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifier),
            keccak256("EUR"), // EUR not supported
            newRate
        );
    }

    function test_updateDepositConversionRate_RevertUnsupportedVerifier() public {
        uint256 newRate = 2e18;
        address unsupportedVerifier = makeAddr("unsupportedVerifier");

        // Try to update rate for unsupported verifier
        vm.prank(alice);
        vm.expectRevert("Currency or verifier not supported");
        escrow.updateDepositConversionRate(
            depositId,
            unsupportedVerifier,
            keccak256("USD"),
            newRate
        );
    }

    function test_updateDepositConversionRate_RevertZeroRate() public {
        uint256 zeroRate = 0;

        // Try to update with zero rate
        vm.prank(alice);
        vm.expectRevert("Conversion rate must be greater than 0");
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifier),
            keccak256("USD"),
            zeroRate
        );
    }

    function test_updateDepositConversionRate_RevertNonExistentDeposit() public {
        uint256 nonExistentDepositId = 999;
        uint256 newRate = 2e18;

        // Try to update rate for non-existent deposit
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.OnlyDepositor.selector));
        escrow.updateDepositConversionRate(
            nonExistentDepositId,
            address(tossBankReclaimVerifier),
            keccak256("USD"),
            newRate
        );
    }

    function test_updateDepositConversionRate_RevertWhenPaused() public {
        uint256 newRate = 2e18;

        // Pause the contract
        vm.prank(escrowOwner);
        escrow.pause();

        // Try to update rate when paused
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifier),
            keccak256("USD"),
            newRate
        );
    }

    function test_updateDepositConversionRate_MultipleUpdates() public {
        uint256 firstRate = 1.5e18;
        uint256 secondRate = 2.5e18;
        uint256 thirdRate = 1.8e18;

        // First update
        vm.prank(alice);
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifier),
            keccak256("USD"),
            firstRate
        );
        
        uint256 rate1 = escrow.depositCurrencyConversionRate(
            depositId, 
            address(tossBankReclaimVerifier), 
            keccak256("USD")
        );
        assertEq(rate1, firstRate);

        // Second update
        vm.prank(alice);
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifier),
            keccak256("USD"),
            secondRate
        );
        
        uint256 rate2 = escrow.depositCurrencyConversionRate(
            depositId, 
            address(tossBankReclaimVerifier), 
            keccak256("USD")
        );
        assertEq(rate2, secondRate);

        // Third update
        vm.prank(alice);
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifier),
            keccak256("USD"),
            thirdRate
        );
        
        uint256 rate3 = escrow.depositCurrencyConversionRate(
            depositId, 
            address(tossBankReclaimVerifier), 
            keccak256("USD")
        );
        assertEq(rate3, thirdRate);
    }

    function test_updateDepositConversionRate_AffectsNewIntents() public {
        uint256 newUsdRate = 2e18; // 2.0 conversion rate
        uint256 intentAmount = 1000e6; // 1000 USDT

        // Update USD conversion rate
        vm.prank(alice);
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifier),
            keccak256("USD"),
            newUsdRate
        );

        // Signal new intent - should use updated conversion rate
        vm.prank(bob);
        escrow.signalIntent(
            depositId,
            intentAmount,
            bob,
            address(tossBankReclaimVerifier),
            keccak256("USD")
        );

        uint256 intentId = escrow.accountIntent(bob);
        
        // Check that intent uses the updated conversion rate
        (,,,,,, , uint256 conversionRate) = escrow.intents(intentId);
        assertEq(conversionRate, newUsdRate);
    }

    function test_updateDepositConversionRate_DoesNotAffectExistingIntents() public {
        uint256 intentAmount = 1000e6; // 1000 USDT
        uint256 originalRate = 1e18;

        // Signal intent with original conversion rate
        vm.prank(bob);
        escrow.signalIntent(
            depositId,
            intentAmount,
            bob,
            address(tossBankReclaimVerifier),
            keccak256("USD")
        );

        uint256 intentId = escrow.accountIntent(bob);
        
        // Check original conversion rate in intent
        (,,,,,, , uint256 originalConversionRate) = escrow.intents(intentId);
        assertEq(originalConversionRate, originalRate);

        // Update conversion rate after intent creation
        uint256 newRate = 2e18;
        vm.prank(alice);
        escrow.updateDepositConversionRate(
            depositId,
            address(tossBankReclaimVerifier),
            keccak256("USD"),
            newRate
        );

        // Check that existing intent still has original conversion rate
        (,,,,,, , uint256 unchangedConversionRate) = escrow.intents(intentId);
        assertEq(unchangedConversionRate, originalRate);
        
        // Verify deposit has new rate
        uint256 depositRate = escrow.depositCurrencyConversionRate(
            depositId, 
            address(tossBankReclaimVerifier), 
            keccak256("USD")
        );
        assertEq(depositRate, newRate);
    }
}
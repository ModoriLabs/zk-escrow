// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseTest.sol";
import { Escrow } from "../../src/Escrow.sol";
import { IEscrow } from "../../src/interfaces/IEscrow.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CreateDepositTest is BaseTest {
    address public escrowOwner;
    address public usdtOwner;

    function setUp() public override {
        super.setUp();

        escrowOwner = escrow.owner();
        usdtOwner = usdt.owner();

        // Mint USDT to test users
        vm.startPrank(usdtOwner);
        usdt.mint(alice, 100000e6); // 100,000 USDT
        usdt.mint(bob, 50000e6);    // 50,000 USDT
        vm.stopPrank();

        // Whitelist the verifier for tests
        vm.prank(escrowOwner);
        escrow.addWhitelistedPaymentVerifier(address(tossBankReclaimVerifier));
    }

    function _createDeposit() internal returns (uint256 depositId) {
        uint256 depositAmount = 10000e6; // 10,000 USDT
        IEscrow.Range memory intentRange = IEscrow.Range({
            min: 100e6,  // Min 100 USDT per intent
            max: 1000e6  // Max 1,000 USDT per intent
        });

        // Setup verifiers array
        address[] memory verifiers = new address[](1);
        verifiers[0] = address(tossBankReclaimVerifier);

        // Setup verifier data
        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](1);
        verifierData[0] = IEscrow.DepositVerifierData({
            payeeDetails: "test-payee-details",
            data: abi.encode("test-data")
        });

        // Setup currencies
        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](1);
        currencies[0] = new IEscrow.Currency[](1);
        currencies[0][0] = IEscrow.Currency({
            code: keccak256("USD"),
            conversionRate: 1e18
        });

        // Approve escrow to spend USDT
        vm.startPrank(alice);
        usdt.approve(address(escrow), depositAmount);

        // Create deposit
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

    function test_createDeposit_Success() public {
        uint256 depositAmount = 10000e6; // 10,000 USDT
        IEscrow.Range memory intentRange = IEscrow.Range({
            min: 100e6,  // Min 100 USDT per intent
            max: 1000e6  // Max 1,000 USDT per intent
        });
        
        // Check initial balances
        uint256 aliceBalanceBefore = usdt.balanceOf(alice);
        uint256 escrowBalanceBefore = usdt.balanceOf(address(escrow));
        
        // Create deposit using helper function
        uint256 depositId = _createDeposit();
        
        // Verify deposit was created correctly
        {
            (
                address depositor,
                IERC20 token,
                uint256 amount,
                IEscrow.Range memory storedRange,
                bool acceptingIntents,
                uint256 remainingDeposits,
                uint256 outstandingIntentAmount
            ) = escrow.deposits(depositId);

            assertEq(depositor, alice);
            assertEq(address(token), address(usdt));
            assertEq(amount, depositAmount);
            assertEq(storedRange.min, intentRange.min);
            assertEq(storedRange.max, intentRange.max);
            assertTrue(acceptingIntents);
            assertEq(remainingDeposits, depositAmount);
            assertEq(outstandingIntentAmount, 0);

            // Verify account deposits mapping
            assertEq(escrow.accountDeposits(alice, 0), depositId);

            // Verify balances changed correctly
            assertEq(usdt.balanceOf(alice), aliceBalanceBefore - depositAmount);
            assertEq(usdt.balanceOf(address(escrow)), escrowBalanceBefore + depositAmount);

            // Verify currency conversion rate was set
            assertEq(escrow.depositCurrencyConversionRate(depositId, address(tossBankReclaimVerifier), keccak256("USD")), 1e18);

            // Verify verifier was added to deposit
            assertEq(escrow.depositVerifiers(depositId, 0), address(tossBankReclaimVerifier));

            // Verify deposit counter incremented
            assertEq(escrow.depositCounter(), 1);
        }
    }

    function test_createDeposit_MultipleVerifiers() public {
        uint256 depositAmount = 10000e6;
        IEscrow.Range memory intentRange = IEscrow.Range({ min: 100e6, max: 1000e6 });

        // Setup multiple verifiers
        address[] memory verifiers = new address[](2);
        verifiers[0] = address(tossBankReclaimVerifier);
        verifiers[1] = alice; // Use alice as second verifier for testing

        // Whitelist alice as verifier
        vm.prank(escrowOwner);
        escrow.addWhitelistedPaymentVerifier(alice);

        // Setup verifier data for both
        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](2);
        verifierData[0] = IEscrow.DepositVerifierData({
            payeeDetails: "toss-bank-details",
            data: abi.encode("toss-data")
        });
        verifierData[1] = IEscrow.DepositVerifierData({
            payeeDetails: "other-verifier-details",
            data: abi.encode("other-data")
        });

        // Setup currencies for each verifier
        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](2);

        // First verifier supports USD
        currencies[0] = new IEscrow.Currency[](1);
        currencies[0][0] = IEscrow.Currency({ code: keccak256("USD"), conversionRate: 1e18 });

        // Second verifier supports USD and EUR
        currencies[1] = new IEscrow.Currency[](2);
        currencies[1][0] = IEscrow.Currency({ code: keccak256("USD"), conversionRate: 1e18 });
        currencies[1][1] = IEscrow.Currency({ code: keccak256("EUR"), conversionRate: 12e17 }); // 1.2 conversion rate

        vm.startPrank(bob);
        usdt.approve(address(escrow), depositAmount);

        uint256 depositId = escrow.createDeposit(
            IERC20(address(usdt)),
            depositAmount,
            intentRange,
            verifiers,
            verifierData,
            currencies
        );
        vm.stopPrank();

        // Verify currency conversion rates were set up
        assertEq(escrow.depositCurrencyConversionRate(depositId, address(tossBankReclaimVerifier), keccak256("USD")), 1e18);
        assertEq(escrow.depositCurrencyConversionRate(depositId, alice, keccak256("USD")), 1e18);
        assertEq(escrow.depositCurrencyConversionRate(depositId, alice, keccak256("EUR")), 12e17);

        // Verify both verifiers were added
        assertEq(escrow.depositVerifiers(depositId, 0), address(tossBankReclaimVerifier));
        assertEq(escrow.depositVerifiers(depositId, 1), alice);
    }

    function test_createDeposit_MultipleDeposits() public {
        uint256 deposit1Amount = 5000e6;
        uint256 deposit2Amount = 3000e6;

        IEscrow.Range memory range1 = IEscrow.Range({ min: 50e6, max: 500e6 });
        IEscrow.Range memory range2 = IEscrow.Range({ min: 100e6, max: 1000e6 });

        // Setup common test data
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

        // First deposit
        vm.startPrank(alice);
        usdt.approve(address(escrow), deposit1Amount + deposit2Amount);

        uint256 depositId1 = escrow.createDeposit(
            IERC20(address(usdt)),
            deposit1Amount,
            range1,
            verifiers,
            verifierData,
            currencies
        );

        // Second deposit
        uint256 depositId2 = escrow.createDeposit(
            IERC20(address(usdt)),
            deposit2Amount,
            range2,
            verifiers,
            verifierData,
            currencies
        );
        vm.stopPrank();

        // Verify both deposits exist
        assertEq(escrow.accountDeposits(alice, 0), depositId1);
        assertEq(escrow.accountDeposits(alice, 1), depositId2);

        // Verify deposit counter incremented correctly
        assertEq(escrow.depositCounter(), 2);
    }

    function test_createDeposit_RevertWhenPaused() public {
        // Pause the contract
        vm.prank(escrowOwner);
        escrow.pause();

        uint256 depositAmount = 1000e6;
        IEscrow.Range memory intentRange = IEscrow.Range({ min: 10e6, max: 100e6 });

        // Setup test data
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
    }

    function test_createDeposit_RevertInvalidIntentRange() public {
        uint256 depositAmount = 1000e6;

        // Test case 1: min = 0
        IEscrow.Range memory invalidRange1 = IEscrow.Range({ min: 0, max: 100e6 });

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

        vm.expectRevert("Invalid intent amount range");
        escrow.createDeposit(
            IERC20(address(usdt)),
            depositAmount,
            invalidRange1,
            verifiers,
            verifierData,
            currencies
        );

        // Test case 2: min > max
        IEscrow.Range memory invalidRange2 = IEscrow.Range({ min: 100e6, max: 50e6 });

        vm.expectRevert("Invalid intent amount range");
        escrow.createDeposit(
            IERC20(address(usdt)),
            depositAmount,
            invalidRange2,
            verifiers,
            verifierData,
            currencies
        );

        // Test case 3: min > amount
        IEscrow.Range memory invalidRange3 = IEscrow.Range({ min: 2000e6, max: 3000e6 });

        vm.expectRevert("Amount must be greater than min intent amount");
        escrow.createDeposit(
            IERC20(address(usdt)),
            depositAmount,
            invalidRange3,
            verifiers,
            verifierData,
            currencies
        );

        vm.stopPrank();
    }

    function test_createDeposit_RevertEmptyVerifiers() public {
        uint256 depositAmount = 1000e6;
        IEscrow.Range memory intentRange = IEscrow.Range({ min: 100e6, max: 1000e6 });

        // Empty verifiers array
        address[] memory verifiers = new address[](0);
        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](0);
        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](0);

        vm.startPrank(alice);
        usdt.approve(address(escrow), depositAmount);

        vm.expectRevert("Invalid verifiers");
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

    function test_createDeposit_RevertMismatchedArrayLengths() public {
        uint256 depositAmount = 1000e6;
        IEscrow.Range memory intentRange = IEscrow.Range({ min: 100e6, max: 1000e6 });

        // Test mismatched verifier data length
        address[] memory verifiers1 = new address[](1);
        verifiers1[0] = address(tossBankReclaimVerifier);

        IEscrow.DepositVerifierData[] memory verifierData1 = new IEscrow.DepositVerifierData[](2); // Wrong length
        IEscrow.Currency[][] memory currencies1 = new IEscrow.Currency[][](1);

        vm.startPrank(alice);
        usdt.approve(address(escrow), depositAmount * 3); // Approve enough for all tests

        vm.expectRevert("Invalid verifier data");
        escrow.createDeposit(
            IERC20(address(usdt)),
            depositAmount,
            intentRange,
            verifiers1,
            verifierData1,
            currencies1
        );

        // Test mismatched currencies length
        address[] memory verifiers2 = new address[](1);
        verifiers2[0] = address(tossBankReclaimVerifier);

        IEscrow.DepositVerifierData[] memory verifierData2 = new IEscrow.DepositVerifierData[](1);
        verifierData2[0] = IEscrow.DepositVerifierData({
            payeeDetails: "test-payee",
            data: abi.encode("test")
        });

        IEscrow.Currency[][] memory currencies2 = new IEscrow.Currency[][](2); // Wrong length

        vm.expectRevert("Invalid currencies length");
        escrow.createDeposit(
            IERC20(address(usdt)),
            depositAmount,
            intentRange,
            verifiers2,
            verifierData2,
            currencies2
        );

        vm.stopPrank();
    }

    function test_createDeposit_RevertInsufficientBalance() public {
        uint256 userBalance = usdt.balanceOf(alice);
        uint256 depositAmount = userBalance + 1; // Try to deposit more than balance
        IEscrow.Range memory intentRange = IEscrow.Range({ min: 10e6, max: 100e6 });

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

        vm.expectRevert(); // ERC20: transfer amount exceeds balance
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

    function test_createDeposit_RevertInsufficientAllowance() public {
        uint256 depositAmount = 1000e6;
        IEscrow.Range memory intentRange = IEscrow.Range({ min: 10e6, max: 100e6 });

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
        // Don't approve, so transfer should fail

        vm.expectRevert(); // ERC20: insufficient allowance
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

    function test_createDeposit_RevertDuplicateCurrency() public {
        uint256 depositAmount = 1000e6;
        IEscrow.Range memory intentRange = IEscrow.Range({ min: 100e6, max: 1000e6 });

        address[] memory verifiers = new address[](1);
        verifiers[0] = address(tossBankReclaimVerifier);

        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](1);
        verifierData[0] = IEscrow.DepositVerifierData({
            payeeDetails: "test-payee",
            data: abi.encode("test")
        });

        // Setup duplicate currencies
        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](1);
        currencies[0] = new IEscrow.Currency[](2);
        currencies[0][0] = IEscrow.Currency({ code: keccak256("USD"), conversionRate: 1e18 });
        currencies[0][1] = IEscrow.Currency({ code: keccak256("USD"), conversionRate: 12e17 }); // Duplicate USD

        vm.startPrank(alice);
        usdt.approve(address(escrow), depositAmount);

        vm.expectRevert("Currency conversion rate already exists");
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
}

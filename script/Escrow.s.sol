// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/src/Script.sol";
import { Escrow } from "src/Escrow.sol";
import { IEscrow } from "src/interfaces/IEscrow.sol";
import { MockUSDT } from "src/MockUSDT.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TossBankReclaimVerifierV2 } from "src/verifiers/TossBankReclaimVerifierV2.sol";
import { BaseScript } from "./Base.s.sol";

contract EscrowScript is BaseScript {
    Escrow public escrow;
    MockUSDT public usdt;
    address public verifier;
    uint256 public KRW_CONVERSION_RATE = 1380e18;
    address public constant VERIFIER_ADDRESS_V2 = 0x2042c7E7A36CAB186189946ad751EAAe6769E661;

    function setUp() public {
        // Load deployed contract addresses from environment or use defaults
        escrow = Escrow(_getDeployedAddress("Escrow"));
        usdt = MockUSDT(_getDeployedAddress("MockUSDT"));
        verifier = _getDeployedAddress("TossBankReclaimVerifierV2");
    }

    function createDeposit(
        uint256 amount,
        uint256 minIntent,
        uint256 maxIntent,
        string memory payeeDetails
    ) public returns (uint256 depositId) {
        address depositor = broadcaster;

        console.log("Creating deposit:");
        console.log("- Depositor:", depositor);
        console.log("- Amount (USDT):", amount / 1e6);
        // console.log("- Intent range:", minIntent / 1e6, "-", maxIntent / 1e6, "USDT");

        vm.startBroadcast();

        // Check USDT balance
        uint256 balance = usdt.balanceOf(depositor);
        require(balance >= amount, "Insufficient USDT balance");

        // Approve Escrow to spend USDT
        usdt.approve(address(escrow), amount);

        // Prepare deposit parameters
        IEscrow.Range memory intentRange = IEscrow.Range({
            min: minIntent,
            max: maxIntent
        });

        address[] memory verifiers = new address[](1);
        verifiers[0] = verifier;

        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](1);
        address[] memory witnessAddresses = new address[](1);
        // Test witness address from TossBankReclaimVerifierV2.t.sol
        witnessAddresses[0] = VERIFIER_ADDRESS_V2;
        verifierData[0] = IEscrow.DepositVerifierData({
            payeeDetails: payeeDetails,
            data: abi.encode(witnessAddresses)
        });

        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](1);
        currencies[0] = new IEscrow.Currency[](1);
        currencies[0][0] = IEscrow.Currency({
            code: keccak256("KRW"),
            conversionRate: KRW_CONVERSION_RATE
        });

        depositId = escrow.createDeposit(
            IERC20(address(usdt)),
            amount,
            intentRange,
            verifiers,
            verifierData,
            currencies
        );

        console.log("Deposit created with ID:", depositId);

        vm.stopBroadcast();
    }

    function signalIntent(
        uint256 depositId,
        uint256 amount,
        address to,
        bytes32 currency
    ) public returns (uint256 intentId) {
        address signer = broadcaster;

        console.log("Signaling intent:");
        console.log("- Signer:", signer);
        console.log("- Deposit ID:", depositId);
        console.log("- Amount (USDT):", amount / 1e6);
        console.log("- To:", to);

        vm.startBroadcast();

        escrow.signalIntent(
            depositId,
            amount,
            to,
            verifier,
            currency
        );

        intentId = escrow.accountIntent(signer);
        console.log("Intent created with ID:", intentId);

        vm.stopBroadcast();
    }

    function fulfillIntent(
        bytes memory paymentProof,
        uint256 intentId
    ) public {
        address fulfiller = broadcaster;

        console.log("Fulfilling intent ID:", intentId);
        console.log("- Fulfiller:", fulfiller);

        vm.startBroadcast();

        escrow.fulfillIntent(paymentProof, intentId);

        console.log("Intent fulfilled successfully!");

        vm.stopBroadcast();
    }

    function cancelIntent(uint256 intentId) public {
        address canceller = broadcaster;

        console.log("Canceling intent ID:", intentId);

        vm.startBroadcast();

        escrow.cancelIntent(intentId);

        console.log("Intent canceled successfully!");

        vm.stopBroadcast();
    }

    function increaseDeposit(uint256 depositId, uint256 amount) public {
        address depositor = broadcaster;

        console.log("Increasing deposit:");
        console.log("- Deposit ID:", depositId);
        console.log("- Additional amount (USDT):", amount / 1e6);
        console.log("- Depositor:", depositor);

        vm.startBroadcast();

        // Check current balance
        uint256 balance = usdt.balanceOf(depositor);
        require(balance >= amount, "Insufficient USDT balance");

        // Approve escrow to spend additional USDT
        usdt.approve(address(escrow), amount);

        // Increase the deposit
        escrow.increaseDeposit(depositId, amount);

        console.log("Deposit increased successfully!");

        vm.stopBroadcast();
    }

    function updateDepositConversionRate(uint256 depositId, uint256 conversionRate) public {
        vm.startBroadcast();
        bytes32 currency = keccak256("KRW");
        uint256 oldConversionRate = escrow.depositCurrencyConversionRate(depositId, verifier, currency);
        escrow.updateDepositConversionRate(depositId, verifier, currency, conversionRate);
        console.log("Deposit conversion rate updated successfully!");
        console.log("Old conversion rate:", oldConversionRate);
        console.log("New conversion rate:", conversionRate);
        vm.stopBroadcast();
    }

    // Convenience functions with default parameters
    function run() public {
        console.log("Use one of the specific functions:");
        console.log("- createDeposit(amount, minIntent, maxIntent, payeeDetails)");
        console.log("- signalIntent(depositId, amount, to, currency)");
        console.log("- fulfillIntent(paymentProof, intentId)");
        console.log("- cancelIntent(intentId)");
        console.log("- increaseDeposit(depositId, amount)");
        console.log("- checkDeployments() - Check if contracts are deployed");
    }

    // Helper function to check deployment status
    function checkDeployments() public view {
        console.log("=== Contract Deployment Status ===");
        console.log("Escrow address:", address(escrow));
        console.log("USDT address:", address(usdt));
        console.log("Verifier address:", verifier);

        // Check if contracts exist
        address escrowAddr = address(escrow);
        address usdtAddr = address(usdt);
        address verifierAddr = verifier;

        uint256 escrowCodeSize;
        uint256 usdtCodeSize;
        uint256 verifierCodeSize;
        assembly {
            escrowCodeSize := extcodesize(escrowAddr)
            usdtCodeSize := extcodesize(usdtAddr)
            verifierCodeSize := extcodesize(verifierAddr)
        }

        console.log("Escrow deployed:", escrowCodeSize > 0);
        console.log("USDT deployed:", usdtCodeSize > 0);
        console.log("Verifier deployed:", verifierCodeSize > 0);

        if (escrowCodeSize == 0) {
            console.log("ERROR: Escrow not deployed. Run deploy script first.");
        }
        if (usdtCodeSize == 0) {
            console.log("ERROR: MockUSDT not deployed. Run deploy script first.");
        }
        if (verifierCodeSize == 0) {
            console.log("ERROR: Verifier not deployed. Run deploy script first.");
        }

        // Check USDT balance for the current user
        address depositor = broadcaster;

        if (usdtCodeSize > 0) {
            uint256 balance = usdt.balanceOf(depositor);
            console.log("User address:", depositor);
            console.log("USDT balance:", balance / 1e6);

            if (balance == 0) {
                console.log("WARNING: No USDT balance. Mint tokens first if needed.");
            }
        }
    }

    // Example usage functions
    function createDefaultDeposit() public returns (uint256) {
        return createDeposit(
            10000e6,  // 10,000 USDT
            1000,     // 1000/1000000 USDT * 1380 WON/USDT = 1.38 WON
            2000e6,   // 2,000 USDT max per intent
            unicode"100202642943(토스뱅크)"
        );
    }

    function signalDefaultIntent(uint256 depositId) public returns (uint256) {
        return signalIntent(
            depositId,
            500e6,  // 500 USDT
            broadcaster,  // to self
            keccak256("KRW")
        );
    }

    // Helper view functions
    function viewDeposit(uint256 depositId) public view {
        (
            address depositor,
            IERC20 token,
            uint256 amount,
            IEscrow.Range memory range,
            bool acceptingIntents,
            uint256 remainingDeposits,
            uint256 outstandingIntentAmount
        ) = escrow.deposits(depositId);

        console.log("Deposit details for ID:", depositId);
        console.log("- Depositor:", depositor);
        console.log("- Token:", address(token));
        console.log("- Total amount (USDT):", amount / 1e6);
        console.log("- Intent range min (USDT):", range.min / 1e6);
        console.log("- Intent range max (USDT):", range.max / 1e6);
        console.log("- Accepting intents:", acceptingIntents);
        console.log("- Remaining (USDT):", remainingDeposits / 1e6);
        console.log("- Outstanding (USDT):", outstandingIntentAmount / 1e6);
    }

    function viewIntent(uint256 intentId) public view {
        (
            address owner,
            address to,
            uint256 depositId,
            uint256 amount,
            uint256 timestamp,
            address paymentVerifier,
            bytes32 fiatCurrency,
            uint256 conversionRate
        ) = escrow.intents(intentId);

        console.log("Intent details for ID:", intentId);
        console.log("- Owner:", owner);
        console.log("- To:", to);
        console.log("- Deposit ID:", depositId);
        console.log("- Amount (USDT):", amount / 1e6);
        console.log("- Timestamp:", timestamp);
        console.log("- Verifier:", paymentVerifier);
        console.log("- Conversion rate:", conversionRate);
    }
}

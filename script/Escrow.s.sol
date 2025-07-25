// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/src/Script.sol";
import { Escrow } from "src/Escrow.sol";
import { IEscrow } from "src/interfaces/IEscrow.sol";
import { MockUSDT } from "src/MockUSDT.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TossBankReclaimVerifierV2 } from "src/verifiers/TossBankReclaimVerifierV2.sol";

contract EscrowScript is Script {
    Escrow public escrow;
    MockUSDT public usdt;
    address public verifier;

    function setUp() public {
        // Load deployed contract addresses from environment or use defaults
        escrow = Escrow(vm.envOr("ESCROW_ADDRESS", address(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0)));
        usdt = MockUSDT(vm.envOr("USDT_ADDRESS", address(0x5FbDB2315678afecb367f032d93F642f64180aa3)));
        verifier = vm.envOr("VERIFIER_ADDRESS", address(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9));
    }

        function createDeposit(
        uint256 amount,
        uint256 minIntent,
        uint256 maxIntent,
        string memory payeeDetails
    ) public returns (uint256 depositId) {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address depositor = vm.addr(deployerPrivateKey);

        console.log("Creating deposit:");
        console.log("- Depositor:", depositor);
        console.log("- Amount (USDT):", amount / 1e6);
        // console.log("- Intent range:", minIntent / 1e6, "-", maxIntent / 1e6, "USDT");

        vm.startBroadcast(deployerPrivateKey);

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

        // TODO: check
        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](1);
        address[] memory witnessAddresses = new address[](1);
        witnessAddresses[0] = address(0x2042c7E7A36CAB186189946ad751EAAe6769E661); // Test witness address from
            // TossBankReclaimVerifierV2.t.sol
        verifierData[0] =
            IEscrow.DepositVerifierData({ payeeDetails: payeeDetails, data: abi.encode(witnessAddresses) });

        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](1);
        currencies[0] = new IEscrow.Currency[](2);
        currencies[0][0] = IEscrow.Currency({
            code: keccak256("USD"),
            conversionRate: 1e18
        });
        currencies[0][1] = IEscrow.Currency({
            code: keccak256("KRW"),
            conversionRate: 1380e18
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
        uint256 signerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address signer = vm.addr(signerPrivateKey);

        console.log("Signaling intent:");
        console.log("- Deposit ID:", depositId);
        console.log("- Amount (USDT):", amount / 1e6);
        console.log("- To:", to);

        vm.startBroadcast(signerPrivateKey);

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
        uint256 fulfillerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address fulfiller = vm.addr(fulfillerPrivateKey);

        console.log("Fulfilling intent ID:", intentId);

        vm.startBroadcast(fulfillerPrivateKey);

        escrow.fulfillIntent(paymentProof, intentId);

        console.log("Intent fulfilled successfully!");

        vm.stopBroadcast();
    }

    function cancelIntent(uint256 intentId) public {
        uint256 cancellerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address canceller = vm.addr(cancellerPrivateKey);

        console.log("Canceling intent ID:", intentId);

        vm.startBroadcast(cancellerPrivateKey);

        escrow.cancelIntent(intentId);

        console.log("Intent canceled successfully!");

        vm.stopBroadcast();
    }

    function increaseDeposit(uint256 depositId, uint256 amount) public {
        uint256 depositorPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address depositor = vm.addr(depositorPrivateKey);

        console.log("Increasing deposit:");
        console.log("- Deposit ID:", depositId);
        console.log("- Additional amount (USDT):", amount / 1e6);
        console.log("- Depositor:", depositor);

        vm.startBroadcast(depositorPrivateKey);

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
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address depositor = vm.addr(deployerPrivateKey);

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
            2000e6,   // 2,000 USDT max
            unicode"100202642943(토스뱅크)"
        );
    }

    function signalDefaultIntent(uint256 depositId) public returns (uint256) {
        return signalIntent(
            depositId,
            500e6,  // 500 USDT
            msg.sender,  // to self
            keccak256("USD")
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

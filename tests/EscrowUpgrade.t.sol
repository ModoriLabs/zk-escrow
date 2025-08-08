// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./BaseEscrowUpgradeableTest.sol";
import { EscrowUpgradeable } from "../src/EscrowUpgradeable.sol";
import { IEscrow } from "../src/interfaces/IEscrow.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Mock V2 contract for testing upgrades
contract EscrowUpgradeableV2 is EscrowUpgradeable {
    uint256 public newStateVariable;

    function setNewStateVariable(uint256 _value) external onlyOwner {
        newStateVariable = _value;
    }

    function getVersion() external pure returns (string memory) {
        return "2.0.0";
    }
}

contract EscrowUpgradeTest is BaseEscrowUpgradeableTest {
    EscrowUpgradeable public escrowV2Implementation;

    function setUp() public override {
        super.setUp();
    }

    function test_UpgradeToV2_Success() public {
        // Create a deposit and signal an intent before upgrade
        uint256 depositId = _createDeposit(alice, 10_000e6, 100e6, 2000e6);
        uint256 intentId = _signalIntent(bob, depositId, 500e6, charlie);

        // Record counters before upgrade
        uint256 intentCountBefore = escrow.intentCount();
        uint256 depositCounterBefore = escrow.depositCounter();

        // Deploy and upgrade
        EscrowUpgradeableV2 newImplementation = new EscrowUpgradeableV2();
        vm.prank(escrowOwner);
        escrow.upgradeToAndCall(address(newImplementation), "");

        // Cast to V2 and verify upgrade succeeded
        EscrowUpgradeableV2 escrowV2 = EscrowUpgradeableV2(address(escrow));
        assertEq(escrowV2.getVersion(), "2.0.0", "Version should be 2.0.0");

        // Verify state preservation
        assertEq(escrow.intentCount(), intentCountBefore, "Intent count should be preserved");
        assertEq(escrow.depositCounter(), depositCounterBefore, "Deposit counter should be preserved");

        // Verify deposit data preserved
        _verifyDepositPreserved(depositId, alice, 10_000e6);

        // Verify intent data preserved
        _verifyIntentPreserved(intentId, bob, charlie, 500e6);

        // Test new functionality
        vm.prank(escrowOwner);
        escrowV2.setNewStateVariable(42);
        assertEq(escrowV2.newStateVariable(), 42, "New state variable should be set");
    }

    function test_UpgradeToV2_OnlyOwnerCanUpgrade() public {
        EscrowUpgradeableV2 newImplementation = new EscrowUpgradeableV2();

        // Non-owner tries to upgrade
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        escrow.upgradeToAndCall(address(newImplementation), "");

        // Owner can upgrade
        vm.prank(escrowOwner);
        escrow.upgradeToAndCall(address(newImplementation), "");
    }

    function test_UpgradeWithActiveDepositsAndIntents() public {
        // Create a deposit matching the proof fixture pattern
        IEscrow.Range memory intentRange = IEscrow.Range({ min: 100, max: 1000e6 });
        
        address[] memory verifiers = new address[](1);
        verifiers[0] = address(tossBankReclaimVerifierV2);

        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](1);
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
        usdt.approve(address(escrow), 5000e6);
        uint256 deposit1 = escrow.createDeposit(IERC20(address(usdt)), 5000e6, intentRange, verifiers, verifierData, currencies);
        vm.stopPrank();
        
        uint256 deposit2 = _createDeposit(charlie, 15_000e6, 50e6, 3000e6);

        // Signal intents - use the same pattern as FulfillIntent test
        uint256 intentAmount = 9420; // 0.00942 USDT to match proof
        uint256 intent1 = _signalIntent(bob, deposit1, intentAmount, bob); // recipient is bob to match proof

        // Create a new user for the second intent
        address user2 = makeAddr("user2");
        uint256 intent2 = _signalIntent(user2, deposit2, 500e6, address(0x2222));

        // Record balances
        uint256 contractBalance = usdt.balanceOf(address(escrow));

        // Deploy and upgrade
        EscrowUpgradeableV2 newImplementation = new EscrowUpgradeableV2();
        vm.prank(escrowOwner);
        escrow.upgradeToAndCall(address(newImplementation), "");

        // Verify contract still holds funds
        assertEq(usdt.balanceOf(address(escrow)), contractBalance, "Contract balance should remain unchanged");

        // Verify deposits still work
        (,,uint256 amount1,,,,) = _getDeposit(deposit1);
        (,,uint256 amount2,,,,) = _getDeposit(deposit2);
        assertEq(amount1, 5000e6, "Deposit 1 amount preserved");
        assertEq(amount2, 15_000e6, "Deposit 2 amount preserved");

        // Verify intents still work
        (,,,uint256 intentAmount1,,,,) = _getIntent(intent1);
        (,,,uint256 intentAmount2,,,,) = _getIntent(intent2);
        assertEq(intentAmount1, intentAmount, "Intent 1 amount preserved");
        assertEq(intentAmount2, 500e6, "Intent 2 amount preserved");

        // Verify we can still fulfill intents after upgrade
        uint256 bobBalanceBefore = usdt.balanceOf(bob);
        _loadProofV2();
        vm.prank(bob);
        escrow.fulfillIntent(abi.encode(proof), intent1);

        // Verify fulfillment worked
        uint256 bobBalanceAfter = usdt.balanceOf(bob);
        assertEq(bobBalanceAfter - bobBalanceBefore, intentAmount, "Intent should be fulfilled to bob");
    }

    function test_UpgradePreservesWhitelistedVerifiers() public {
        // Add another verifier before upgrade
        address newVerifier = address(0x9999);
        vm.prank(escrowOwner);
        escrow.addWhitelistedPaymentVerifier(newVerifier);

        assertTrue(escrow.whitelistedPaymentVerifiers(address(tossBankReclaimVerifierV2)), "Original verifier should be whitelisted");
        assertTrue(escrow.whitelistedPaymentVerifiers(newVerifier), "New verifier should be whitelisted");

        // Upgrade
        EscrowUpgradeableV2 newImplementation = new EscrowUpgradeableV2();
        vm.prank(escrowOwner);
        escrow.upgradeToAndCall(address(newImplementation), "");

        // Verify verifiers still whitelisted
        assertTrue(escrow.whitelistedPaymentVerifiers(address(tossBankReclaimVerifierV2)), "Original verifier should remain whitelisted");
        assertTrue(escrow.whitelistedPaymentVerifiers(newVerifier), "New verifier should remain whitelisted");
    }

    function test_UpgradePreservesGovernanceSettings() public {
        // Modify governance settings before upgrade
        vm.startPrank(escrowOwner);
        escrow.setIntentExpirationPeriod(3600); // 1 hour
        escrow.setMaxIntentsPerDeposit(50);
        escrow.pause();
        vm.stopPrank();

        assertEq(escrow.intentExpirationPeriod(), 3600, "Intent expiration should be set");
        assertEq(escrow.maxIntentsPerDeposit(), 50, "Max intents should be set");
        assertTrue(escrow.paused(), "Contract should be paused");

        // Upgrade
        EscrowUpgradeableV2 newImplementation = new EscrowUpgradeableV2();
        vm.prank(escrowOwner);
        escrow.upgradeToAndCall(address(newImplementation), "");

        // Verify settings preserved
        assertEq(escrow.intentExpirationPeriod(), 3600, "Intent expiration should be preserved");
        assertEq(escrow.maxIntentsPerDeposit(), 50, "Max intents should be preserved");
        assertTrue(escrow.paused(), "Paused state should be preserved");

        // Unpause to verify it still works
        vm.prank(escrowOwner);
        escrow.unpause();
        assertFalse(escrow.paused(), "Contract should be unpaused");
    }

    function test_UpgradeWithInitializerFunction() public {
        // Deploy V2 with initializer
        EscrowUpgradeableV2 newImplementation = new EscrowUpgradeableV2();

        // Prepare initializer call
        bytes memory initData = abi.encodeWithSelector(
            EscrowUpgradeableV2.setNewStateVariable.selector,
            999
        );

        // Upgrade with initializer
        vm.prank(escrowOwner);
        escrow.upgradeToAndCall(address(newImplementation), initData);

        // Verify initializer was called
        EscrowUpgradeableV2 escrowV2 = EscrowUpgradeableV2(address(escrow));
        assertEq(escrowV2.newStateVariable(), 999, "Initializer should have set new state variable");
    }

    function test_StorageSlotConsistency() public {
        // Create some state
        uint256 depositId = _createDeposit(alice, 10_000e6, 100e6, 2000e6);
        _signalIntent(bob, depositId, 500e6, charlie);

        // Get storage slot values before upgrade
        bytes32 slot0 = vm.load(address(escrow), bytes32(uint256(0)));
        bytes32 slot1 = vm.load(address(escrow), bytes32(uint256(1)));

        // Upgrade
        EscrowUpgradeableV2 newImplementation = new EscrowUpgradeableV2();
        vm.prank(escrowOwner);
        escrow.upgradeToAndCall(address(newImplementation), "");

        // Verify storage slots remain the same
        bytes32 slot0After = vm.load(address(escrow), bytes32(uint256(0)));
        bytes32 slot1After = vm.load(address(escrow), bytes32(uint256(1)));

        assertEq(slot0, slot0After, "Storage slot 0 should remain unchanged");
        assertEq(slot1, slot1After, "Storage slot 1 should remain unchanged");
    }

    function test_ImplementationAddressChanges() public {
        // Get current implementation using vm.load to read the implementation slot
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address currentImpl = address(uint160(uint256(vm.load(address(escrow), implSlot))));
        assertEq(currentImpl, address(escrowImplementation), "Current implementation should match");

        // Deploy and upgrade
        EscrowUpgradeableV2 newImplementation = new EscrowUpgradeableV2();
        vm.prank(escrowOwner);
        escrow.upgradeToAndCall(address(newImplementation), "");

        // Verify implementation changed
        address newImpl = address(uint160(uint256(vm.load(address(escrow), implSlot))));
        assertEq(newImpl, address(newImplementation), "Implementation should be updated");
        assertTrue(newImpl != currentImpl, "Implementation address should have changed");
    }

    // Helper function to verify deposit data is preserved
    function _verifyDepositPreserved(uint256 depositId, address expectedDepositor, uint256 expectedAmount) internal view {
        (address depositor, IERC20 token, uint256 amount,,,,) = escrow.deposits(depositId);
        assertEq(depositor, expectedDepositor, "Depositor should be preserved");
        assertEq(address(token), address(usdt), "Token should be preserved");
        assertEq(amount, expectedAmount, "Deposit amount should be preserved");
    }

    // Helper function to verify intent data is preserved
    function _verifyIntentPreserved(uint256 intentId, address expectedOwner, address expectedTo, uint256 expectedAmount) internal view {
        (address owner, address to,, uint256 amount,,,,) = escrow.intents(intentId);
        assertEq(owner, expectedOwner, "Intent owner should be preserved");
        assertEq(to, expectedTo, "Intent recipient should be preserved");
        assertEq(amount, expectedAmount, "Intent amount should be preserved");
    }
}

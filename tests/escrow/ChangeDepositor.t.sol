// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseEscrowUpgradeableTest.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract ChangeDepositorTest is BaseEscrowUpgradeableTest {
    uint256 depositId;
    address newDepositor = makeAddr("newDepositor");

    function setUp() public override {
        super.setUp();

        // Create a deposit as alice
        depositId = _createDeposit(alice, 10_000e6, 100e6, 2000e6);
    }

    function test_ChangeDepositor_Success() public {
        // Verify initial state
        (address depositor,,,,,,) = escrow.deposits(depositId);
        assertEq(depositor, alice, "Initial depositor should be alice");

        // Check alice's account deposits include this deposit
        uint256 aliceDepositCount = _getAccountDepositsLength(alice);
        assertTrue(aliceDepositCount > 0, "Alice should have deposits");

        // Change depositor
        vm.prank(alice);
        escrow.changeDepositor(depositId, newDepositor);

        // Verify depositor changed
        (address updatedDepositor,,,,,,) = escrow.deposits(depositId);
        assertEq(updatedDepositor, newDepositor, "Depositor should be updated");

        // Verify alice's account deposits no longer include this deposit
        uint256 aliceDepositCountAfter = _getAccountDepositsLength(alice);
        assertEq(aliceDepositCountAfter, aliceDepositCount - 1, "Alice's deposit count should decrease");

        // Verify new depositor's account deposits include this deposit
        uint256 newDepositorDepositCount = _getAccountDepositsLength(newDepositor);
        assertEq(newDepositorDepositCount, 1, "New depositor should have one deposit");
        assertEq(
            escrow.accountDeposits(newDepositor, 0), depositId, "New depositor's first deposit should be this depositId"
        );
    }

    function test_ChangeDepositor_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IEscrow.DepositDepositorChanged(depositId, alice, newDepositor);

        vm.prank(alice);
        escrow.changeDepositor(depositId, newDepositor);
    }

    function test_ChangeDepositor_OnlyCurrentDepositor() public {
        // Bob tries to change alice's deposit
        vm.prank(bob);
        vm.expectRevert(IEscrow.OnlyDepositor.selector);
        escrow.changeDepositor(depositId, newDepositor);
    }

    function test_ChangeDepositor_RevertZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(IEscrow.InvalidAddress.selector);
        escrow.changeDepositor(depositId, address(0));
    }

    function test_ChangeDepositor_RevertSameAddress() public {
        vm.prank(alice);
        vm.expectRevert(IEscrow.InvalidAddress.selector);
        escrow.changeDepositor(depositId, alice);
    }

    function test_RevertWhen_ChangeDepositor_WhenPaused() public {
        // Pause the contract
        vm.prank(escrowOwner);
        escrow.pause();

        // Try to change depositor
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        escrow.changeDepositor(depositId, newDepositor);
    }

    function test_ChangeDepositor_WithActiveIntent() public {
        // Signal an intent on the deposit
        uint256 intentId = _signalIntent(bob, depositId, 500e6, charlie);

        // Change depositor should still work
        vm.prank(alice);
        escrow.changeDepositor(depositId, newDepositor);

        // Verify intent is still active
        (address intentOwner,,, uint256 intentAmount,,,,) = escrow.intents(intentId);
        assertEq(intentOwner, bob, "Intent owner should remain unchanged");
        assertEq(intentAmount, 500e6, "Intent amount should remain unchanged");

        // Get Charlie's balance before release
        uint256 charlieBalBefore = usdt.balanceOf(charlie);

        // New depositor should be able to perform depositor-only actions
        vm.prank(newDepositor);
        escrow.releaseFundsToPayer(intentId);

        // Verify funds were released
        uint256 charlieBalAfter = usdt.balanceOf(charlie);
        assertEq(charlieBalAfter - charlieBalBefore, 500e6, "Charlie should receive the intent amount");
    }

    function test_ChangeDepositor_CanWithdrawAfterChange() public {
        // Change depositor
        vm.prank(alice);
        escrow.changeDepositor(depositId, newDepositor);

        // New depositor should be able to withdraw
        uint256 balanceBefore = usdt.balanceOf(newDepositor);

        vm.prank(newDepositor);
        escrow.withdrawDeposit(depositId);

        uint256 balanceAfter = usdt.balanceOf(newDepositor);
        assertEq(balanceAfter - balanceBefore, 10_000e6, "New depositor should receive full deposit amount");
    }

    function test_ChangeDepositor_MultipleDeposits() public {
        // Create another deposit as alice
        uint256 depositId2 = _createDeposit(alice, 5000e6, 50e6, 1000e6);

        // Verify alice has 2 deposits
        assertEq(_getAccountDepositsLength(alice), 2, "Alice should have 2 deposits");

        // Change depositor of first deposit
        vm.prank(alice);
        escrow.changeDepositor(depositId, newDepositor);

        // Verify alice still has the second deposit
        assertEq(_getAccountDepositsLength(alice), 1, "Alice should have 1 deposit");
        assertEq(escrow.accountDeposits(alice, 0), depositId2, "Alice should still have depositId2");

        // Verify new depositor has the first deposit
        assertEq(_getAccountDepositsLength(newDepositor), 1, "New depositor should have 1 deposit");
        assertEq(escrow.accountDeposits(newDepositor, 0), depositId, "New depositor should have depositId");
    }

    // Helper function to get account deposits length
    function _getAccountDepositsLength(address account) internal view returns (uint256) {
        uint256 count = 0;
        while (true) {
            try escrow.accountDeposits(account, count) returns (uint256) {
                count++;
            } catch {
                break;
            }
        }
        return count;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseEscrowUpgradeableTest.sol";

contract IncreaseDepositTest is BaseEscrowUpgradeableTest {
    uint256 public depositId;
    uint256 public initialDepositAmount = 10_000e6; // 10,000 USDT

    function setUp() public override {
        super.setUp();

        // Create initial deposit
        depositId = _createDeposit();
    }

    function test_increaseDeposit_Success() public {
        uint256 additionalAmount = 5000e6; // 5,000 USDT

        // Check initial state
        (
            address depositor,
            IERC20 token,
            uint256 amountBefore,
            ,
            bool acceptingIntents,
            uint256 remainingBefore,
            uint256 outstanding
        ) = escrow.deposits(depositId);

        assertEq(depositor, alice);
        assertEq(address(token), address(usdt));
        assertEq(amountBefore, initialDepositAmount);
        assertTrue(acceptingIntents);
        assertEq(remainingBefore, initialDepositAmount);
        assertEq(outstanding, 0);

        uint256 aliceBalanceBefore = usdt.balanceOf(alice);
        uint256 escrowBalanceBefore = usdt.balanceOf(address(escrow));

        // Approve additional amount
        vm.prank(alice);
        usdt.approve(address(escrow), additionalAmount);

        // Increase deposit
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit IEscrow.DepositIncreased(depositId, alice, additionalAmount, initialDepositAmount + additionalAmount);

        escrow.increaseDeposit(depositId, additionalAmount);

        // Check state after increase
        (,, uint256 amountAfter,,, uint256 remainingAfter, uint256 outstandingAfter) = escrow.deposits(depositId);

        assertEq(amountAfter, initialDepositAmount + additionalAmount);
        assertEq(remainingAfter, initialDepositAmount + additionalAmount);
        assertEq(outstandingAfter, 0);

        // Check balances
        assertEq(usdt.balanceOf(alice), aliceBalanceBefore - additionalAmount);
        assertEq(usdt.balanceOf(address(escrow)), escrowBalanceBefore + additionalAmount);
    }

    function test_increaseDeposit_RevertNonExistentDeposit() public {
        uint256 nonExistentDepositId = 999;
        uint256 additionalAmount = 5000e6;

        vm.prank(alice);
        usdt.approve(address(escrow), additionalAmount);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.DepositNotFound.selector));
        escrow.increaseDeposit(nonExistentDepositId, additionalAmount);
    }

    function test_increaseDeposit_RevertWhenPaused() public {
        uint256 additionalAmount = 5000e6;

        // Pause the contract
        vm.prank(escrowOwner);
        escrow.pause();

        vm.prank(alice);
        usdt.approve(address(escrow), additionalAmount);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.increaseDeposit(depositId, additionalAmount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseTest.sol";

contract CancelIntentTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_cancelIntent_ClearAccountIntent() public {
        address sender = address(this);
        _signalIntent();

        // Verify intent exists before cancellation
        assertEq(zkMinter.accountIntent(sender), 1);

        // Cancel the intent
        zkMinter.cancelIntent(1);

        // Verify intent is cleared after cancellation
        assertEq(zkMinter.accountIntent(sender), 0);
    }

    function test_cancelIntent_ClearIntentStorage() public {
        _signalIntent();

        // Verify intent exists in storage
        (address owner, address to, uint256 amount, uint256 timestamp, address verifier) = zkMinter.intents(1);
        assertEq(owner, address(this));
        assertEq(to, alice);
        assertEq(amount, TEST_AMOUNT);
        assertEq(verifier, address(tossBankReclaimVerifier));
        assertTrue(timestamp > 0);

        // Cancel the intent
        zkMinter.cancelIntent(1);

        // Verify intent is cleared from storage
        (address ownerAfter, address toAfter, uint256 amountAfter, uint256 timestampAfter, address verifierAfter) = zkMinter.intents(1);
        assertEq(ownerAfter, address(0));
        assertEq(toAfter, address(0));
        assertEq(amountAfter, 0);
        assertEq(timestampAfter, 0);
        assertEq(verifierAfter, address(0));
    }

    function test_cancelIntent_EmitsEvent() public {
        _signalIntent();

        // Expect IntentCancelled event to be emitted
        vm.expectEmit(true, false, false, true);
        emit IZkMinter.IntentCancelled(1);

        zkMinter.cancelIntent(1);
    }

    function test_cancelIntent_AllowsNewIntentAfter() public {
        address sender = address(this);
        _signalIntent();

        // Cancel the intent
        zkMinter.cancelIntent(1);

        // Should be able to signal a new intent after cancellation
        zkMinter.signalIntent({
            _to: alice,
            _amount: TEST_AMOUNT,
            _verifier: address(tossBankReclaimVerifier)
        });

        // Verify new intent was created
        assertEq(zkMinter.accountIntent(sender), 2);
        assertEq(zkMinter.intentCount(), 2);
    }

    function test_RevertWhen_cancelIntent_NotOwner() public {
        _signalIntent();

        // Try to cancel from a different address
        vm.prank(alice);
        vm.expectRevert("Sender must be the intent owner");
        zkMinter.cancelIntent(1);
    }

    function test_RevertWhen_cancelIntent_IntentDoesNotExist() public {
        // Try to cancel a non-existent intent
        vm.expectRevert("Sender must be the intent owner");
        zkMinter.cancelIntent(999);
    }

    function test_cancelIntent_WorksWhenPaused() public {
        _signalIntent();

        // Pause the contract
        vm.prank(owner);
        zkMinter.pause();

        // Cancel should still work when paused (as per function comment)
        zkMinter.cancelIntent(1);

        // Verify intent was cancelled
        assertEq(zkMinter.accountIntent(address(this)), 0);
    }
}

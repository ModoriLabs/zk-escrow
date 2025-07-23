// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../BaseTest.sol";

contract SignalIntentTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_signalIntent_IncrementIntentCount() public {
        _signalIntent();
        assertEq(zkMinter.intentCount(), 1);
    }

    function test_signalIntent_UpdateAccountIntent() public {
        address sender = address(this);
        _signalIntent();
        assertEq(zkMinter.accountIntent(sender), 1);
    }

    function test_signalIntent_EmitsEvent() public {
        // Expect IntentSignaled event to be emitted
        vm.expectEmit(true, true, true, true);
        emit IZkMinter.IntentSignaled(alice, address(tossBankReclaimVerifier), TEST_AMOUNT, 1);

        _signalIntent();
    }

    function test_RevertWhen_signalIntent_WithZeroAmount() public {
        vm.expectRevert(IZkMinter.InvalidAmount.selector);
        zkMinter.signalIntent({
            _to: alice,
            _amount: 0,
            _verifier: address(tossBankReclaimVerifier)
        });
    }

    function test_RevertWhen_signalIntent_WithZeroAddress() public {
        vm.expectRevert("Invalid recipient address");
        zkMinter.signalIntent({
            _to: address(0),
            _amount: 100,
            _verifier: address(tossBankReclaimVerifier)
        });
    }

    function test_RevertWhen_signalIntent_WithInvalidVerifier() public {
        vm.expectRevert("Invalid verifier address");
        zkMinter.signalIntent({
            _to: alice,
            _amount: 100,
            _verifier: address(0)
        });
    }

    function test_RevertWhen_signalIntent_IntentAlreadyExists() public {
        _signalIntent();

        vm.expectRevert("Intent already exists for this address");
        zkMinter.signalIntent({
            _to: alice,
            _amount: 200,
            _verifier: address(tossBankReclaimVerifier)
        });
    }
}

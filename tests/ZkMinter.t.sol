// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./BaseTest.sol";

contract ZkMinterTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_signalIntent_IncrementIntentCount() public {
        _signalIntent();
        assertEq(zkMinter.intentCount(), 1);
    }

    function test_signalIntent_UpdateAccountIntent() public {
        _signalIntent();
        assertEq(zkMinter.accountIntent(alice), 1);
    }

    function test_CancelIntent() public {
        // TODO:
    }

    function test_RevertWhen_fulfillIntent_WithWrongIntentId() public {
        vm.expectRevert(IZkMinter.IntentNotFound.selector);
        _fulfillIntent();
    }

    function test_fulfillIntent_clearAccountIntent() public {
        _signalIntent();
        _loadProof();
        _fulfillIntent();
    }

    function _signalIntent() internal {
        zkMinter.signalIntent({
            _to: alice,
            _amount: 100,
            _verifier: address(tossBankReclaimVerifier)
        });
    }

    function _fulfillIntent() internal {
        _loadProof();
        bytes memory paymentProof = abi.encode(proof);
        zkMinter.fulfillIntent({
            _paymentProof: paymentProof,
            _intentId: 1
        });
    }
}

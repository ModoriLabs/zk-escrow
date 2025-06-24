// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./BaseTest.sol";

contract ZkMinterTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_signalIntent_IncrementIntentCount() public {

    }

    function test_CancelIntent() public {
        // TODO:
    }

    function test_fulfillIntent_clearAccountIntent() public {
    }

    function _signalIntent() internal {
        zkMinter.signalIntent({
            _to: alice,
            _amount: 100,
            _verifier: address(tossBankReclaimVerifier)
        });
    }
}

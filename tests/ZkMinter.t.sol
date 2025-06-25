// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./BaseTest.sol";

contract ZkMinterTest is BaseTest {
    uint256 constant TEST_AMOUNT = 8750e6; // 8750 USDT with 6 decimals

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

    function test_CancelIntent() public {
        // TODO:
    }

    function test_RevertWhen_fulfillIntent_WithWrongIntentId() public {
        vm.expectRevert(IZkMinter.IntentNotFound.selector);
        _fulfillIntent();
    }

    function test_fulfillIntent_ClearAccountIntent() public {
        address sender = address(this);
        _signalIntent();
        _loadProof();

        // Verify intent exists before fulfillment
        assertEq(zkMinter.accountIntent(sender), 1);

        _fulfillIntent();

        // Verify intent is cleared after fulfillment
        assertEq(zkMinter.accountIntent(sender), 0);
    }

    function test_fulfillIntent_MintTokens() public {
        _signalIntent();
        _loadProof();

        // Check initial balance
        uint256 initialBalance = usdt.balanceOf(alice);

        _fulfillIntent();

        // Verify tokens were minted correctly
        assertEq(usdt.balanceOf(alice), initialBalance + TEST_AMOUNT);
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

    function test_fulfillIntent_CompleteFlow() public {
        // Test the complete flow: signal -> verify -> fulfill
        address sender = address(this);
        uint256 initialBalance = usdt.balanceOf(alice);
        uint256 initialIntentCount = zkMinter.intentCount();

        // Signal intent
        _signalIntent();

        // Verify intent was created correctly
        assertEq(zkMinter.intentCount(), initialIntentCount + 1);
        assertEq(zkMinter.accountIntent(sender), 1);

        // Get intent details
        (address owner, address to, uint256 amount, uint256 timestamp, address verifier) = zkMinter.intents(1);
        assertEq(owner, address(this));
        assertEq(to, alice);
        assertEq(amount, TEST_AMOUNT);
        assertEq(verifier, address(tossBankReclaimVerifier));
        assertTrue(timestamp > 0);

        // Fulfill intent
        _loadProof();
        _fulfillIntent();

        // Verify final state
        assertEq(usdt.balanceOf(alice), initialBalance + TEST_AMOUNT);
        assertEq(zkMinter.accountIntent(sender), 0);
    }

    function _signalIntent() internal {
        zkMinter.signalIntent({
            _to: alice,
            _amount: 8750e6,
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

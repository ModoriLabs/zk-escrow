// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./BaseTest.sol";

contract ZkMinterTest is BaseTest {
    function setUp() public override {
        super.setUp();
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
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "../BaseTest.sol";

contract FulfillRedeemTest is BaseTest {
    uint256 constant REDEEM_AMOUNT = 1000e6; // 1000 USDT with 6 decimals
    string constant ACCOUNT_NUMBER = "1234567890";

    function setUp() public override {
        super.setUp();
    }

    // Helper function to signal a redeem request
    function _signalRedeem() internal {
        vm.startPrank(alice);
        // Approve the zkMinter contract to spend alice's tokens
        usdt.approve(address(zkMinter), REDEEM_AMOUNT);
        // Signal the redeem request
        zkMinter.signalRedeem(ACCOUNT_NUMBER, REDEEM_AMOUNT);
        vm.stopPrank();
    }

    // Helper function to mint tokens to alice for redeem tests
    function _mintTokensToAlice() internal {
        // Since ZkMinter is the owner of USDT, we need to prank as the zkMinter contract
        vm.prank(address(zkMinter));
        usdt.mint(alice, REDEEM_AMOUNT);
    }

    function test_signalRedeem_EmitsEvent() public {
        _mintTokensToAlice();

        vm.startPrank(alice);
        usdt.approve(address(zkMinter), REDEEM_AMOUNT);

        // Expect RedeemRequestSignaled event to be emitted with correct parameters
        vm.expectEmit(true, true, false, true);
        emit IZkMinter.RedeemRequestSignaled(1, alice, REDEEM_AMOUNT, ACCOUNT_NUMBER);

        zkMinter.signalRedeem(ACCOUNT_NUMBER, REDEEM_AMOUNT);
        vm.stopPrank();
    }

    function test_fulfillRedeem_Success() public {
        // Setup: mint tokens to alice and signal a redeem request
        _mintTokensToAlice();
        _signalRedeem();

        // Verify redeem request exists
        (address requestOwner, uint256 amount, uint256 timestamp) = zkMinter.redeemRequests(1);
        assertEq(requestOwner, alice);
        assertEq(amount, REDEEM_AMOUNT);
        assertTrue(timestamp > 0);

        // Get initial token balance and verify escrow
        uint256 initialBalance = usdt.balanceOf(alice);
        assertEq(initialBalance, 0); // Alice should have 0 tokens after signaling redeem
        assertEq(usdt.balanceOf(address(zkMinter)), REDEEM_AMOUNT); // Contract should hold the tokens

        // Fulfill the redeem request as owner
        vm.prank(owner);
        zkMinter.fulfillRedeem(1);

        // Verify redeem request is cleared
        (address ownerAfter, uint256 amountAfter, uint256 timestampAfter) = zkMinter.redeemRequests(1);
        assertEq(ownerAfter, address(0));
        assertEq(amountAfter, 0);
        assertEq(timestampAfter, 0);

        // Verify alice's account mapping is cleared
        assertEq(zkMinter.accountRedeemRequest(alice), 0);
    }

    function test_fulfillRedeem_EmitsEvent() public {
        _mintTokensToAlice();
        _signalRedeem();

        // Expect RedeemRequestFulfilled event to be emitted
        vm.expectEmit(true, false, false, true);
        emit IZkMinter.RedeemRequestFulfilled(1);

        vm.prank(owner);
        zkMinter.fulfillRedeem(1);
    }

    function test_fulfillRedeem_AllowsNewRedeemAfter() public {
        _mintTokensToAlice();
        _signalRedeem();

        // Fulfill the redeem request
        vm.prank(owner);
        zkMinter.fulfillRedeem(1);

        // Mint more tokens to Alice for the second redeem request
        vm.prank(address(zkMinter));
        usdt.mint(alice, REDEEM_AMOUNT);

        // Alice should be able to signal a new redeem request
        vm.startPrank(alice);
        usdt.approve(address(zkMinter), REDEEM_AMOUNT);
        zkMinter.signalRedeem(ACCOUNT_NUMBER, REDEEM_AMOUNT);
        vm.stopPrank();

        // Verify new redeem request was created
        assertEq(zkMinter.accountRedeemRequest(alice), 2);
        assertEq(zkMinter.redeemCount(), 2);
    }

    function test_fulfillRedeem_MultipleRequests() public {
        address bob = makeAddr("bob");

        // Setup: mint tokens to both alice and bob
        _mintTokensToAlice();
        vm.prank(address(zkMinter));
        usdt.mint(bob, REDEEM_AMOUNT);

                // Both users signal redeem requests
        _signalRedeem(); // alice signals redeem (id = 1)

        // Bob approves and signals redeem
        vm.startPrank(bob);
        usdt.approve(address(zkMinter), REDEEM_AMOUNT);
        zkMinter.signalRedeem(ACCOUNT_NUMBER, REDEEM_AMOUNT); // bob signals redeem (id = 2)
        vm.stopPrank();

        // Fulfill alice's redeem request
        vm.prank(owner);
        zkMinter.fulfillRedeem(1);

        // Verify alice's request is cleared but bob's remains
        assertEq(zkMinter.accountRedeemRequest(alice), 0);
        assertEq(zkMinter.accountRedeemRequest(bob), 2);

        // Verify bob's request still exists
        (address bobOwner, uint256 bobAmount, uint256 bobTimestamp) = zkMinter.redeemRequests(2);
        assertEq(bobOwner, bob);
        assertEq(bobAmount, REDEEM_AMOUNT);
        assertTrue(bobTimestamp > 0);
    }

    function test_RevertWhen_fulfillRedeem_NotOwner() public {
        _mintTokensToAlice();
        _signalRedeem();

        // Try to fulfill as non-owner
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        zkMinter.fulfillRedeem(1);
    }

    function test_RevertWhen_fulfillRedeem_RequestNotFound() public {
        // Try to fulfill a non-existent redeem request
        vm.prank(owner);
        vm.expectRevert(IZkMinter.RedeemRequestNotFound.selector);
        zkMinter.fulfillRedeem(999);
    }

    function test_RevertWhen_fulfillRedeem_AlreadyFulfilled() public {
        _mintTokensToAlice();
        _signalRedeem();

        // Fulfill the redeem request
        vm.prank(owner);
        zkMinter.fulfillRedeem(1);

        // Try to fulfill the same request again
        vm.prank(owner);
        vm.expectRevert(IZkMinter.RedeemRequestNotFound.selector);
        zkMinter.fulfillRedeem(1);
    }

    function test_fulfillRedeem_WithZeroAmount() public {
        // This test verifies that if somehow a redeem request with 0 amount exists,
        // it should be caught by the RedeemRequestNotFound error
        vm.prank(owner);
        vm.expectRevert(IZkMinter.RedeemRequestNotFound.selector);
        zkMinter.fulfillRedeem(1);
    }

        function test_fulfillRedeem_DecrementsTotalSupply() public {
        _mintTokensToAlice();
        uint256 initialTotalSupply = usdt.totalSupply();

        _signalRedeem();

        // Total supply should remain the same after signaling (tokens just moved to escrow)
        assertEq(usdt.totalSupply(), initialTotalSupply);

        vm.prank(owner);
        zkMinter.fulfillRedeem(1);

        // Total supply should decrease after burning
        uint256 finalTotalSupply = usdt.totalSupply();
        assertEq(finalTotalSupply, initialTotalSupply - REDEEM_AMOUNT);
    }

    function test_fulfillRedeem_WithPausedContract() public {
        _mintTokensToAlice();
        _signalRedeem();

        // Pause the contract
        vm.prank(owner);
        zkMinter.pause();

        // fulfillRedeem should still work when paused (onlyOwner function)
        vm.prank(owner);
        zkMinter.fulfillRedeem(1);

        // Verify redeem request was fulfilled
        assertEq(zkMinter.accountRedeemRequest(alice), 0);
    }

    function test_cancelRedeem_ReturnsTokens() public {
        _mintTokensToAlice();
        uint256 initialBalance = usdt.balanceOf(alice);

        _signalRedeem();

        // Verify tokens are escrowed in the contract
        assertEq(usdt.balanceOf(alice), initialBalance - REDEEM_AMOUNT);
        assertEq(usdt.balanceOf(address(zkMinter)), REDEEM_AMOUNT);

        // Cancel the redeem request
        vm.prank(alice);
        zkMinter.cancelRedeem(1);

        // Verify tokens are returned to alice
        assertEq(usdt.balanceOf(alice), initialBalance);
        assertEq(usdt.balanceOf(address(zkMinter)), 0);

        // Verify redeem request is cleared
        assertEq(zkMinter.accountRedeemRequest(alice), 0);
    }
}

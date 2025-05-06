// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Vault.sol";
import "../src/MockUSDT.sol";

contract VaultTest is Test {
    Vault vault;
    MockERC20 mockUsdt;

    uint256 private constant NOTARY_PRIVATE_KEY = 123; // random private key
    address notary;

    function setUp() public {
        notary = vm.addr(NOTARY_PRIVATE_KEY);
        console2.log("Notary address: %s", notary);

        mockUsdt = new MockERC20();

        vault = new Vault(address(mockUsdt), notary);
        mockUsdt.mint(address(vault), 100 * 1e6);
    }

    function testEnroll() public {
        uint256 orderId = 361130000883032064;
        uint64 binanceId = 123456;
        uint256 amount = 5 * 1e6; // 5 USDT with 6 decimals
        vault.enroll(orderId, binanceId, amount);
        (uint64 binanceId_, uint256 amount_, bool claimed_) = vault.enrollments(orderId);
        assertEq(binanceId_, binanceId);
        assertEq(amount_, amount);
        assertEq(claimed_, false);
    }

    function testEnrollTooMuch() public {
        uint256 orderId = 361130000883032064;
        uint64 binanceId = 123456;
        uint256 amount = 11 * 1e6; // 11 USDT with 6 decimals, exceeds the 10 USDT limit
        vm.expectRevert("Amount exceeds 10 USDT limit");
        vault.enroll(orderId, binanceId, amount);
    }

    function testClaim() public {
        uint256 orderId = 361130000883032064;
        uint64 binanceId = 123456;
        uint256 amount = 8 * 1e6; // 8 USDT with 6 decimals
        // new user
        address recipient = address(0x7777);

        vault.enroll(orderId, binanceId, amount);

        // make message hash (same as Vault.claim)
        bytes32 messageHash = keccak256(abi.encodePacked(orderId, recipient, amount));
        console2.logBytes32(messageHash);

        // sign message with notary's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(NOTARY_PRIVATE_KEY, messageHash);

        uint256 recipientBalanceBefore = mockUsdt.balanceOf(recipient);
        vault.claim(orderId, recipient, amount, v, r, s);
        uint256 recipientBalanceAfter = mockUsdt.balanceOf(recipient);
        assertEq(recipientBalanceAfter - recipientBalanceBefore, amount, "Token transfer did not happen correctly");
    }
}

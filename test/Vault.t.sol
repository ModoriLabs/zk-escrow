// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Vault.sol";
import "../src/MockUSDT.sol";

uint256 constant ORDER_ID = 361130000883032064;
string constant NICK_NAME = "test";

contract VaultTest is Test {
    Vault vault;
    MockUSDT mockUsdt;
    uint256 amount = 5 * 1e6;

    uint256 private constant NOTARY_PRIVATE_KEY = 123; // random private key
    address notary;

    function setUp() public {
        notary = vm.addr(NOTARY_PRIVATE_KEY);
        console2.log("Notary address: %s", notary);

        mockUsdt = new MockUSDT();

        vault = new Vault(address(mockUsdt), notary);
        mockUsdt.mint(address(vault), 100 * 1e6);
    }

    function testEnroll() public {
        vault.enroll(ORDER_ID, NICK_NAME, amount);
        (string memory nickName_, uint256 amount_, bool claimed_) = vault.enrollments(ORDER_ID);
        assertEq(nickName_, NICK_NAME);
        assertEq(amount_, amount);
        assertEq(claimed_, false);
    }

    function testEnrollTooMuch() public {
        uint256 amount = 11 * 1e6; // 11 USDT with 6 decimals, exceeds the 10 USDT limit
        vm.expectRevert("Amount exceeds 10 USDT limit");
        vault.enroll(ORDER_ID, NICK_NAME, amount);
    }

    function testClaim() public {
        uint256 amount = 8 * 1e6; // 8 USDT with 6 decimals
        // new user
        address recipient = address(0x7777);

        vault.enroll(ORDER_ID, NICK_NAME, amount);

        // make message hash (same as Vault.claim)
        bytes32 messageHash = keccak256(abi.encodePacked(ORDER_ID, recipient, amount));
        console2.logBytes32(messageHash);

        // sign message with notary's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(NOTARY_PRIVATE_KEY, messageHash);

        uint256 recipientBalanceBefore = mockUsdt.balanceOf(recipient);
        vault.claim(ORDER_ID, recipient, amount, v, r, s);
        uint256 recipientBalanceAfter = mockUsdt.balanceOf(recipient);
        assertEq(recipientBalanceAfter - recipientBalanceBefore, amount, "Token transfer did not happen correctly");
    }
}

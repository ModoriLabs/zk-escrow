// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Vault.sol";
import "./mocks/MockERC20.sol";

contract VaultTest is Test {
    Vault vault;
    MockERC20 mockUsdt;

    // 테스트용 개인키 정의
    uint256 private constant NOTARY_PRIVATE_KEY = 123; // 임의의 개인키 값
    address notary; // vm.addr로 생성할 주소

    function setUp() public {
        // 개인키로부터 주소 생성
        notary = vm.addr(NOTARY_PRIVATE_KEY);
        console2.log("Notary address: %s", notary);

        // MockERC20 배포
        mockUsdt = new MockERC20();

        // Vault 배포 - MockERC20을 USDT로 사용
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

        // 서명할 메시지 구성 (Vault 컨트랙트의 claim 함수와 동일하게)
        bytes32 messageHash = keccak256(abi.encodePacked(orderId, recipient, amount));
        console2.logBytes32(messageHash);

        // notary의 개인키로 메시지에 서명
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(NOTARY_PRIVATE_KEY, messageHash);

        // ecrecover로 서명자 복구 테스트
        address recoveredSigner = ecrecover(messageHash, v, r, s);
        console2.log("Recovered Signer: %s", recoveredSigner);
        console2.log("Expected Signer (notary): %s", notary);

        // recipient의 claim 전 USDT 잔액 확인
        uint256 recipientBalanceBefore = mockUsdt.balanceOf(recipient);
        vault.claim(messageHash, orderId, recipient, v, r, s);
        uint256 recipientBalanceAfter = mockUsdt.balanceOf(recipient);
        assertEq(recipientBalanceAfter - recipientBalanceBefore, amount, "Token transfer did not happen correctly");
    }
}

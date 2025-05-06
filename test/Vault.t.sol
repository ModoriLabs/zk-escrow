// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Vault.sol";

contract VaultTest is Test {
    Vault vault;
    address usdt = address(0x1234); // mock address

    // 테스트용 개인키 정의
    uint256 private constant NOTARY_PRIVATE_KEY = 123; // 임의의 개인키 값
    address notary; // vm.addr로 생성할 주소

    function setUp() public {
        // 개인키로부터 주소 생성
        notary = vm.addr(NOTARY_PRIVATE_KEY);
        console2.log("Notary address: %s", notary);

        vault = new Vault(usdt, notary);
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
        uint256 amount = 5 * 1e6; // 5 USDT with 6 decimals
        address recipient = address(this);

        console2.log("Recipient: %s", recipient);
        console2.log("Notary: %s", notary);
        console2.log("Current Vault notary: %s", vault.notary());

        // 먼저 enrollment 생성
        vault.enroll(orderId, binanceId, amount);

        // 서명할 메시지 구성 (Vault 컨트랙트의 claim 함수와 동일하게)
        bytes32 messageHash = keccak256(abi.encodePacked(orderId, recipient, amount));
        console2.logBytes32(messageHash);

        // notary의 개인키로 메시지에 서명
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(NOTARY_PRIVATE_KEY, messageHash);

        console2.log("v: %d", v);
        console2.log("r: ");
        console2.logBytes32(r);
        console2.log("s: ");
        console2.logBytes32(s);

        // ecrecover로 서명자 복구 테스트
        address recoveredSigner = ecrecover(messageHash, v, r, s);
        console2.log("Recovered Signer: %s", recoveredSigner);
        console2.log("Expected Signer (notary): %s", notary);

        // 복구된 서명자와 notary가 일치하는지 확인
        bool signatureValid = recoveredSigner == notary;
        console2.log("Signature Valid: %s", signatureValid);

        // 서명으로 claim 실행
        vm.prank(notary);
        vault.claim(messageHash, orderId, recipient, v, r, s);
        console2.log("Claim successful!");

        // 결과 확인
        (uint64 binanceId_, uint256 amount_, bool claimed_) = vault.enrollments(orderId);
        assertEq(binanceId_, binanceId);
        assertEq(amount_, amount);
        assertEq(claimed_, true);
    }
}

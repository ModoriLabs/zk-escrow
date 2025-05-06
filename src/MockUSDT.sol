// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// 테스트용 Mock USDT 컨트랙트
contract MockUSDT {
    mapping(address => uint256) public balanceOf;

    constructor() {
        // 컨트랙트 자체에 충분한 토큰 부여
        balanceOf[address(this)] = 100000 * 1e6; // 100,000 USDT
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        balanceOf[address(this)] -= amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        address from = msg.sender;
        // 테스트용으로는 from 주소의 잔고 체크를 하지 않고 항상 성공하도록 함
        balanceOf[to] += amount;
        balanceOf[from] -= amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        balanceOf[to] += amount;
        balanceOf[from] -= amount;
        return true;
    }
}

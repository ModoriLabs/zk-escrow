// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract MockUSDT {
    mapping(address => uint256) public balanceOf;

    constructor() {
        balanceOf[address(this)] = 100000 * 1e6; // 100,000 USDT
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        balanceOf[address(this)] -= amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        address from = msg.sender;
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

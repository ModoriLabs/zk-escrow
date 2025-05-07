// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";

contract VaultScript is Script {
    Vault public vault;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        address usdt = vm.envAddress("MINATO_USDT_ADDRESS");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address notary = vm.addr(privateKey);
        vault = new Vault(usdt, notary);
        vm.stopBroadcast();
    }
}

// 0x3ff2bcAc5963e79Af91D59fc45c6b050f4C9B37e
// 0x8f46067f6B48C47b9673849Ea9dFB78984029C4e

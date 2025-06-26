// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vault} from "../src/Vault.sol";
import {BaseScript} from "./Base.s.sol";

contract VaultScript is BaseScript {
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

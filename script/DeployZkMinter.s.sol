// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vault} from "../src/Vault.sol";
import {BaseScript} from "./Base.s.sol";

contract VaultScript is BaseScript {
    Vault public vault;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        vm.stopBroadcast();
    }
}

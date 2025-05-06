// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {MockUSDT} from "../src/MockUSDT.sol";
import {Vault} from "../src/Vault.sol";

contract ReadVaultState is Script {
    function run() external view {
        address vaultAddress = vm.envAddress("MINATO_VAULT_ADDRESS");
        Vault vault = Vault(vaultAddress);

        console2.log("USDT Address:", vault.usdt());
        console2.log("Notary Address:", vault.notary());
    }
}

contract TransferUSDTToVault is Script {
    function run() external {
        // Load values from .env
        address vaultAddress = vm.envAddress("MINATO_VAULT_ADDRESS");
        address mockUsdtAddress = vm.envAddress("MINATO_USDT_ADDRESS");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting with private key
        vm.startBroadcast(privateKey);

        address sender = vm.addr(privateKey);
        Vault vault = Vault(vaultAddress);
        MockUSDT usdt = MockUSDT(mockUsdtAddress);

        // 1. Mint 100 USDT to sender
        uint256 amount = 100 * 1e6;
        usdt.mint(sender, amount);
        console2.log("Minted 100 USDT to:", sender);

        // 2. Transfer USDT to Vault (manually calling transfer)
        bool success = usdt.transfer(vaultAddress, amount);
        require(success, "Transfer failed");
        console2.log("Transferred 100 USDT to Vault");

        vm.stopBroadcast();
    }
}

contract CheckUSDTBalance is Script {
    function run() external view {
        address usdtAddress = vm.envAddress("MINATO_USDT_ADDRESS");
        address vaultAddress = vm.envAddress("MINATO_VAULT_ADDRESS");
        uint256 balance = MockUSDT(usdtAddress).balanceOf(vaultAddress);

        console2.log("USDT Balance of", vaultAddress, ":", balance);
    }
}

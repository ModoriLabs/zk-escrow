// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MockUSDT} from "../src/MockUSDT.sol";
import {Vault} from "../src/Vault.sol";

contract ReadVaultState is Script {
    function run() external view {
        address vaultAddress = vm.envAddress("MINATO_VAULT_ADDRESS");
        Vault vault = Vault(vaultAddress);
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
        MockUSDT usdt = MockUSDT(mockUsdtAddress);

        // 1. Mint 100 USDT to sender
        uint256 amount = 100 * 1e6;
        usdt.mint(sender, amount);

        // 2. Transfer USDT to Vault (manually calling transfer)
        bool success = usdt.transfer(vaultAddress, amount);
        require(success, "Transfer failed");

        vm.stopBroadcast();
    }
}

contract CheckUSDTBalance is Script {
    function run() external view {
        address usdtAddress = vm.envAddress("MINATO_USDT_ADDRESS");
        address vaultAddress = vm.envAddress("MINATO_VAULT_ADDRESS");
        uint256 balance = MockUSDT(usdtAddress).balanceOf(vaultAddress);
    }
}

contract Enroll is Script {
    function run() external {
        address vaultAddress = vm.envAddress("MINATO_VAULT_ADDRESS");
        Vault vault = Vault(vaultAddress);
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        uint256 orderId = 333330000000000001;
        uint64 binanceId = 100000;
        uint256 amount = 5 * 1e6;

        vm.startBroadcast(privateKey);
        vault.enroll(orderId, binanceId, amount);
        vm.stopBroadcast();
    }
}

contract Claim is Script {
    function run() external {
        address vaultAddress = vm.envAddress("MINATO_VAULT_ADDRESS");
        Vault vault = Vault(vaultAddress);

        uint256 orderId = 333330000000000001;
        uint256 notaryPrivateKey = vm.envUint("NOTARY_PRIVATE_KEY");
        address recipient = vm.addr(notaryPrivateKey);
        uint256 amount = 5 * 1e6;
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(notaryPrivateKey, keccak256(abi.encodePacked(orderId, recipient, amount)));

        vm.startBroadcast(notaryPrivateKey);
        vault.claim(orderId, recipient, amount, v, r, s);
        vm.stopBroadcast();
    }
}

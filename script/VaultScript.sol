// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { MockUSDT } from "src/MockUSDT.sol";
import { Vault } from "src/Vault.sol";
import "./Base.s.sol";

contract TransferUSDTToVault is BaseScript {
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

contract CheckUSDTBalance is BaseScript {
    function run() external view {
        address usdtAddress = vm.envAddress("MINATO_USDT_ADDRESS");
        address vaultAddress = vm.envAddress("MINATO_VAULT_ADDRESS");
        uint256 balance = MockUSDT(usdtAddress).balanceOf(vaultAddress);
        uint256 senderBalance = MockUSDT(usdtAddress).balanceOf(vm.addr(vm.envUint("PRIVATE_KEY")));
        uint256 recipientBalance = MockUSDT(usdtAddress).balanceOf(vm.envAddress("RECIPIENT_ADDRESS"));

        console.log("Vault balance: %s", balance);
        console.log("Sender balance: %s", senderBalance);
        console.log("Recipient balance: %s", recipientBalance);
    }
}

contract Enroll is BaseScript {
    function run() external {
        address vaultAddress = vm.envAddress("MINATO_VAULT_ADDRESS");
        Vault vault = Vault(vaultAddress);
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address recipientAddress = vm.envAddress("RECIPIENT_ADDRESS");
        uint256 amount = vm.envUint("AMOUNT");
        string memory fromBinanceId = vm.envString("FROM_BINANCE_ID");

        vm.startBroadcast(privateKey);
        vault.enroll(fromBinanceId, recipientAddress, amount);
        vm.stopBroadcast();
    }
}

contract Claim is BaseScript {
    function run() external {
        address vaultAddress = vm.envAddress("MINATO_VAULT_ADDRESS");
        Vault vault = Vault(vaultAddress);

        uint256 notaryPrivateKey = vm.envUint("NOTARY_PRIVATE_KEY");
        address recipient = vm.envAddress("RECIPIENT_ADDRESS");
        uint256 amount = vm.envUint("AMOUNT");

        bytes32 enrollId = vault.recipientToEnrollId(recipient);

        // messageHash should be 84 bytes
        bytes32 messageHash = keccak256(abi.encodePacked(enrollId, amount));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(notaryPrivateKey, messageHash);

        vm.startBroadcast(notaryPrivateKey);
        vault.claim(enrollId, amount, v, r, s);
        vm.stopBroadcast();
    }
}

contract ClearEnrollments is BaseScript {
    function run() external {
        address vaultAddress = vm.envAddress("MINATO_VAULT_ADDRESS");
        Vault vault = Vault(vaultAddress);
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        vault.clearEnrollments();
        vm.stopBroadcast();
    }
}

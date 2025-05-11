
## Getting Started

### Deploy Contracts

```sh
forge script script/DeployMockUSDT.s.sol --rpc-url minato --broadcast --private-key $PRIVATE_KEY
forge script script/DeployVault.s.sol --rpc-url minato --broadcast --private-key $PRIVATE_KEY
```

### Enroll & Claim

```sh
RECIPIENT_ADDRESS=0x189027e3C77b3a92fd01bF7CC4E6a86E77F5034E AMOUNT=1000000 FROM_BINANCE_ID=71035696 forge script script/VaultScript.sol:Enroll --rpc-url minato --broadcast --private-key $PRIVATE_KEY

RECIPIENT_ADDRESS=0x189027e3C77b3a92fd01bF7CC4E6a86E77F5034E AMOUNT=1000000 forge script script/VaultScript.
 sol:Claim --rpc-url minato --broadcast --private-key $PRIVATE_KEY
```

## Contract Addresses

### minato

| Contracts              | Address                                                                                                                         |
|------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| Vault                   | [0x6292f3546cB1A31b501794E32A1F07cbd3641c90](https://soneium-minato.blockscout.com/address/0x6292f3546cB1A31b501794E32A1F07cbd3641c90) |
| MockUSDT                   | [0xBb1CDa2F1F874A4a837302184F3c0159B27C0B41](https://soneium-minato.blockscout.com/address/0xBb1CDa2F1F874A4a837302184F3c0159B27C0B41) |

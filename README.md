
## Getting Started

### Install dependencies

```sh
bun install
```

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

### holesky

- owner: 0x189027e3c77b3a92fd01bf7cc4e6a86e77f5034e

| Contracts                    | Address                                                                                                                  |
|------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| KORTProxy | [0x0350BFB59c0b6dA993E6eBfd0405A7C59B97F253](https://holesky.etherscan.io/address/0x0350BFB59c0b6dA993E6eBfd0405A7C59B97F253) |
| NullifierRegistry | [0x788d432297CA4288EC8E9DDa84da40c5dF70D74e](https://holesky.etherscan.io/address/0x788d432297CA4288EC8E9DDa84da40c5dF70D74e) |
| ZkMinter | [0x42d699d20666DdC54ecdf13ec1c82b612C0BFd50](https://holesky.etherscan.io/address/0x42d699d20666DdC54ecdf13ec1c82b612C0BFd50) |
| TossBankReclaimVerifier | [0x312268a6E0F10391647160E3fF296fAa67EeD453](https://holesky.etherscan.io/address/0x312268a6E0F10391647160E3fF296fAa67EeD453) |

### minato

| Contracts              | Address                                                                                                                         |
|------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| Vault                   | [0x6292f3546cB1A31b501794E32A1F07cbd3641c90](https://soneium-minato.blockscout.com/address/0x6292f3546cB1A31b501794E32A1F07cbd3641c90) |
| MockUSDT                   | [0xBb1CDa2F1F874A4a837302184F3c0159B27C0B41](https://soneium-minato.blockscout.com/address/0xBb1CDa2F1F874A4a837302184F3c0159B27C0B41) |

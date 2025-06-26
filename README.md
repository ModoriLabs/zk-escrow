
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

### TossBankReclaimerVerifier

```sh
forge script script/TossBankReclaimVerifier.s.sol --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY --sig addProviderHash
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
| USDT | [0x0350BFB59c0b6dA993E6eBfd0405A7C59B97F253](https://holesky.etherscan.io/address/0x0350BFB59c0b6dA993E6eBfd0405A7C59B97F253) |
| NullifierRegistry | [0xac9CE0086Aade5F090F5FD09E0c6146719A6DfF5](https://holesky.etherscan.io/address/0xac9CE0086Aade5F090F5FD09E0c6146719A6DfF5) |
| ZkMinter | [0x8C5fBa120D336020894ae468B7816F729d365db0](https://holesky.etherscan.io/address/0x8C5fBa120D336020894ae468B7816F729d365db0) |
| TossBankReclaimVerifier | [0xb223Fa34F97f44A50Afd21edba1eB3F54fae1484](https://holesky.etherscan.io/address/0xb223Fa34F97f44A50Afd21edba1eB3F54fae1484) |

### minato

| Contracts              | Address                                                                                                                         |
|------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| Vault                   | [0x6292f3546cB1A31b501794E32A1F07cbd3641c90](https://soneium-minato.blockscout.com/address/0x6292f3546cB1A31b501794E32A1F07cbd3641c90) |
| MockUSDT                   | [0xBb1CDa2F1F874A4a837302184F3c0159B27C0B41](https://soneium-minato.blockscout.com/address/0xBb1CDa2F1F874A4a837302184F3c0159B27C0B41) |

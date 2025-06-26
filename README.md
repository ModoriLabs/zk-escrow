
## Getting Started

### Install dependencies

```sh
bun install
```

### Deploy Contracts

```sh
forge script script/deploy/DeployKRW.s.sol --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY

forge script script/deploy/DeployZkMinter.s.sol --rpc-url holesky --private-key $TESTNET_PRIVATE_KEY --broadcast
```

### Verify contracts

```sh
forge script script/VerifyContracts.s.sol \
  --rpc-url holesky --private-key $TESTNET_PRIVATE_KEY \
  --sig "verifyAll()" --ffi
```

### ZkMinter

```sh
BANK_ACCOUNT="100000000000(토스뱅크)" forge script script/ZkMinter.s.sol \
  --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY \
  --sig "setVerifierData()"
```

### TossBankReclaimerVerifier

```sh
forge script script/TossBankReclaimVerifier.s.sol --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY --sig addProviderHash
```

## Contract Addresses

### holesky

- owner: 0x189027e3c77b3a92fd01bf7cc4e6a86e77f5034e

| Contracts               | Address                                                                                                                       |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| KRW                     | [0x30F9Cb0c288B06A053fa57448f98bBaC8f1604ED](https://holesky.etherscan.io/address/0x30F9Cb0c288B06A053fa57448f98bBaC8f1604ED) |
| USDT                    | [0x0350BFB59c0b6dA993E6eBfd0405A7C59B97F253](https://holesky.etherscan.io/address/0x0350BFB59c0b6dA993E6eBfd0405A7C59B97F253) |
| NullifierRegistry       | [0x53326A8e6efCec1502E13bBB61EF125EB6207e73](https://holesky.etherscan.io/address/0x53326A8e6efCec1502E13bBB61EF125EB6207e73) |
| ZkMinter                | [0x3185294eb121a4962ce0D77FAF1D503Ae2127179](https://holesky.etherscan.io/address/0x3185294eb121a4962ce0D77FAF1D503Ae2127179) |
| TossBankReclaimVerifier | [0xf6f8eE07842f65B9a59721E0f8c3C7B489b810A5](https://holesky.etherscan.io/address/0xf6f8eE07842f65B9a59721E0f8c3C7B489b810A5) |

### minato

| Contracts              | Address                                                                                                                         |
|------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| Vault                   | [0x6292f3546cB1A31b501794E32A1F07cbd3641c90](https://soneium-minato.blockscout.com/address/0x6292f3546cB1A31b501794E32A1F07cbd3641c90) |
| MockUSDT                   | [0xBb1CDa2F1F874A4a837302184F3c0159B27C0B41](https://soneium-minato.blockscout.com/address/0xBb1CDa2F1F874A4a837302184F3c0159B27C0B41) |

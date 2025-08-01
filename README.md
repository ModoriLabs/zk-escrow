# ZK Escrow

## Description

1. nullifier is `keccak256(abi.encodePacked(dateString, senderNickname))`.

## Getting Started

### Install dependencies

```sh
bun install
```

### Test setup

```sh
forge script script/deploy/DeployEscrowTestSetup.s.sol --rpc-url anvil --broadcast
forge script script/Escrow.s.sol --sig "createDefaultDeposit()" --rpc-url anvil --broadcast
```

### Deploy Contracts

```sh
forge script script/deploy/DeployKRW.s.sol --rpc-url holesky --private-key $TESTNET_PRIVATE_KEY --broadcast

forge script script/deploy/DeployZkMinter.s.sol --rpc-url holesky --private-key $TESTNET_PRIVATE_KEY --broadcast
```

```sh
forge script script/deploy/DeployMockUSDT.s.sol --rpc-url base_sepolia --broadcast

forge script script/deploy/DeployNullifierRegistry.s.sol --rpc-url base_sepolia --broadcast

forge script script/deploy/DeployEscrow.s.sol --rpc-url base_sepolia --private-key $TESTNET_PRIVATE_KEY --broadcast
```

### Verify contracts

#### Base Sepolia

```sh
forge script script/verify/VerifyEscrow.s.sol \
  --rpc-url base_sepolia --private-key $TESTNET_PRIVATE_KEY \
  --sig "verifyAll()"
```

#### Holesky

```sh
forge script script/verify/VerifyZkMinter.s.sol \
  --rpc-url holesky --private-key $TESTNET_PRIVATE_KEY \
  --sig "verifyAll()" --ffi
```

### Escrow contracts

#### Escrow

```sh
forge script script/Escrow.s.sol --rpc-url base_sepolia --private-key $TESTNET_PRIVATE_KEY --broadcast --sig "updateDepositConversionRate(uint256,uint256)" 1 1400000000000000000000
```

### ZkMinter contracts

#### ZkMinter

```sh
BANK_ACCOUNT="100000000000(토스뱅크)" forge script script/ZkMinter.s.sol \
  --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY \
  --sig "setVerifierData()"
```

#### TossBankReclaimerVerifier

```sh
forge script script/TossBankReclaimVerifier.s.sol --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY --sig addProviderHash
```

## Contract Addresses

### base_sepolia (test)

| Contracts                    | Address                                                                                                                  |
|------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| Escrow | [0x02286886C36877D564b2b5532f7de40Dc81f2400](https://sepolia.basescan.org/address/0x02286886C36877D564b2b5532f7de40Dc81f2400) |
| MockUSDT | [0x72f91969485c7efa53990fb0763ffa57ba73f3be](https://sepolia.basescan.org/address/0x72f91969485c7efa53990fb0763ffa57ba73f3be) |
| NullifierRegistry | [0xfE9a7603641e5Ac1cc155C62bAA7242dABf93B5a](https://sepolia.basescan.org/address/0xfE9a7603641e5Ac1cc155C62bAA7242dABf93B5a) |
| TossBankReclaimVerifierV2 | [0x08A773D828Ae1195FE7355e8885bD47456815da1](https://sepolia.basescan.org/address/0x08A773D828Ae1195FE7355e8885bD47456815da1) |

### holesky (prod)

- owner: [0x2042c7E7A36CAB186189946ad751EAAe6769E661](https://holesky.etherscan.io/address/0x2042c7E7A36CAB186189946ad751EAAe6769E661)

| Contracts               | Address                                                                                                                       |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| KRW                     | [0x72f91969485c7eFa53990FB0763fFA57Ba73F3Be](https://holesky.etherscan.io/address/0x72f91969485c7eFa53990FB0763fFA57Ba73F3Be) |
| NullifierRegistry       | [0xfE9a7603641e5Ac1cc155C62bAA7242dABf93B5a](https://holesky.etherscan.io/address/0xfE9a7603641e5Ac1cc155C62bAA7242dABf93B5a) |
| TossBankReclaimVerifier | [0x945926B0945F6028D2A4190760341FCD51250f42](https://holesky.etherscan.io/address/0x945926B0945F6028D2A4190760341FCD51250f42) |
| ZkMinter                | [0xB2bACB93a5046Fa2A9b5709CB06d41dAb0De6D37](https://holesky.etherscan.io/address/0xB2bACB93a5046Fa2A9b5709CB06d41dAb0De6D37) |

### holesky (test)

- owner: 0x189027e3c77b3a92fd01bf7cc4e6a86e77f5034e

| Contracts               | Address                                                                                                                       |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| KRW                     | [0xc3E6F8eA0742B3546798Ae3d81914B86fBd91bC1](https://holesky.etherscan.io/address/0xc3E6F8eA0742B3546798Ae3d81914B86fBd91bC1) |
| NullifierRegistry       | [0xe889eab05a95ADE68CE95CD1672C019B84438347](https://holesky.etherscan.io/address/0xe889eab05a95ADE68CE95CD1672C019B84438347) |
| TossBankReclaimVerifier | [0xFE8516d717eA7e7D031061d371145c346f0464eD](https://holesky.etherscan.io/address/0xFE8516d717eA7e7D031061d371145c346f0464eD) |
| USDT                    | [0x0350BFB59c0b6dA993E6eBfd0405A7C59B97F253](https://holesky.etherscan.io/address/0x0350BFB59c0b6dA993E6eBfd0405A7C59B97F253) |
| ZkMinter                | [0x075cA3A2D60D50654699552bD9d97205c51644aa](https://holesky.etherscan.io/address/0x075cA3A2D60D50654699552bD9d97205c51644aa) |

### minato

| Contracts | Address                                                                                                                                |
|-----------|----------------------------------------------------------------------------------------------------------------------------------------|
| Vault     | [0x6292f3546cB1A31b501794E32A1F07cbd3641c90](https://soneium-minato.blockscout.com/address/0x6292f3546cB1A31b501794E32A1F07cbd3641c90) |
| MockUSDT  | [0xBb1CDa2F1F874A4a837302184F3c0159B27C0B41](https://soneium-minato.blockscout.com/address/0xBb1CDa2F1F874A4a837302184F3c0159B27C0B41) |

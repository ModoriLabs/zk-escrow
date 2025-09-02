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

#### Kaia

Kaia is supported by hardhat, not foundry.

```sh
bun hardhat deploy --network kaia --tags NullifierRegistry
bun run print-deployments --network kaia
```

#### Base

```sh
forge script script/deploy/DeployKRW.s.sol --rpc-url holesky --private-key $TESTNET_PRIVATE_KEY --broadcast

forge script script/deploy/DeployZkMinter.s.sol --rpc-url holesky --private-key $TESTNET_PRIVATE_KEY --broadcast
```

```sh
forge script script/deploy/DeployMockUSDT.s.sol --rpc-url base_sepolia --broadcast

forge script script/deploy/DeployNullifierRegistry.s.sol --rpc-url base_sepolia --broadcast

forge script script/deploy/DeployEscrow.s.sol --rpc-url base_sepolia --private-key $TESTNET_PRIVATE_KEY --broadcast
```

### Upgrade EscrowUpgradeable

```sh
forge script script/deploy/UpgradeableEscrow.s.sol --rpc-url base_sepolia --broadcast
```

### Verify contracts

#### Base

```sh
forge script script/verify/VerifyEscrow.s.sol --rpc-url base_sepolia --sig "verifyAll()"
```

#### Holesky

```sh
forge script script/verify/VerifyZkMinter.s.sol \
  --rpc-url holesky --private-key $TESTNET_PRIVATE_KEY \
  --sig "verifyAll()" --ffi
```

### Escrow contracts

#### Escrow

updateDepositConversionRate

```sh
forge script script/Escrow.s.sol --rpc-url base_sepolia --private-key $TESTNET_PRIVATE_KEY --broadcast --sig "updateDepositConversionRate(uint256,uint256)" 1 1400000000000000000000
```

increaseDeposit

```sh
forge script script/Escrow.s.sol \
    --rpc-url base_sepolia \
    --private-key $TESTNET_PRIVATE_KEY \
    --sig "increaseDeposit(uint256,uint256)" \
    1 \
    10000000 \ # 10 USDC
    --broadcast
```

withdrawDeposit

```sh
forge script script/Escrow.s.sol:EscrowScript --sig "withdrawDeposit(uint256)" 1 --rpc-url base
```

#### Escrow (hardhat)

You can add `--dryRun` to simulate the transaction without executing.

```sh
# Increase deposit
npx hardhat escrow:increase-deposit --deposit-id 1 --amount 10 --network kaia

# Update conversion rate
npx hardhat escrow:update-conversion-rate --deposit-id 1 --rate 1000000000000000000000 --currency USD --network kaia

# Update intent range
npx hardhat escrow:update-intent-range --deposit-id 1 --min 0.1 --max 1 --network kaia
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

### kaia (prod)

| Contracts | Address |
|-----------|---------|
| EscrowUpgradeable | [0x8c9bd74c6796eAf8cB48De320FFbe70021021395](https://kaiascan.io/address/0x8c9bd74c6796eAf8cB48De320FFbe70021021395) |
| EscrowUpgradeable_Implementation | [0xCd531c6f7821D173e56ae9383529D8Ac6fdd13f8](https://kaiascan.io/address/0xCd531c6f7821D173e56ae9383529D8Ac6fdd13f8) |
| EscrowUpgradeable_Proxy | [0x8c9bd74c6796eAf8cB48De320FFbe70021021395](https://kaiascan.io/address/0x8c9bd74c6796eAf8cB48De320FFbe70021021395) |
| NullifierRegistry | [0x18ac6522530f88Cf7d61Dd29609F13397869d330](https://kaiascan.io/address/0x18ac6522530f88Cf7d61Dd29609F13397869d330) |
| TossBankReclaimVerifierV2 | [0x861aA44bDe09bB3878203276487e0aB47239fEA1](https://kaiascan.io/address/0x861aA44bDe09bB3878203276487e0aB47239fEA1) |
| USDT | [0xd077a400968890eacc75cdc901f0356c943e4fdb](https://kaiascan.io/address/0xd077a400968890eacc75cdc901f0356c943e4fdb) |

### kairos (test)

| Contracts | Address |
|-----------|---------|
| EscrowUpgradeable | [0xB2bACB93a5046Fa2A9b5709CB06d41dAb0De6D37](https://kairos.kaiascan.io/address/0xB2bACB93a5046Fa2A9b5709CB06d41dAb0De6D37) |
| MockUSDT | [0xef1E927798fc7d016835d2b8B65367b99919F11E](https://kairos.kaiascan.io/address/0xef1E927798fc7d016835d2b8B65367b99919F11E) |
| NullifierRegistry | [0x72f91969485c7eFa53990FB0763fFA57Ba73F3Be](https://kairos.kaiascan.io/address/0x72f91969485c7eFa53990FB0763fFA57Ba73F3Be) |
| TossBankReclaimVerifierV2 | [0x945926B0945F6028D2A4190760341FCD51250f42](https://kairos.kaiascan.io/address/0x945926B0945F6028D2A4190760341FCD51250f42) |

### base (prod)

- owner: 0xf7c76ee9A092562F8C83283f602AeAcd167e46Fb
- depositor1: 0xD76F3CBC08bf9D07D54ad924b959E7ADd1E26fDE

| Contracts                    | Address                                                                                                                  |
|------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| Escrow | [0x5a790BC3038d6e46B8246127EC05540b424577E4](https://basescan.org/address/0x5a790BC3038d6e46B8246127EC05540b424577E4) |
| EscrowImplementation | [0x36608349faa273D471c39A18F1D632705D96Dfc3](https://basescan.org/address/0x36608349faa273D471c39A18F1D632705D96Dfc3) |
| EscrowProxy | [0x5a790BC3038d6e46B8246127EC05540b424577E4](https://basescan.org/address/0x5a790BC3038d6e46B8246127EC05540b424577E4) |
| NullifierRegistry | [0x517Ce8079ab28652BB1e5742B3B82afb41B8d5CE](https://basescan.org/address/0x517Ce8079ab28652BB1e5742B3B82afb41B8d5CE) |
| TossBankReclaimVerifierV2 | [0xc3D3cDc54a4Ef7d36220604Fd73fa521B6F5Fb6c](https://basescan.org/address/0xc3D3cDc54a4Ef7d36220604Fd73fa521B6F5Fb6c) |
| USDC | [0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913](https://basescan.org/address/0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913) |

### base_sepolia (test)

| Contracts                    | Address                                                                                                                  |
|------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| Escrow | [0x90f1bc9C597902B7A60836B63F084d9aC5a657cd](https://sepolia.basescan.org/address/0x90f1bc9C597902B7A60836B63F084d9aC5a657cd) |
| EscrowImplementation | [0xcB80C4D5db2cE157d3EfF1d3ba0FAAe7C25B287F](https://sepolia.basescan.org/address/0xcB80C4D5db2cE157d3EfF1d3ba0FAAe7C25B287F) |
| EscrowProxy | [0x90f1bc9C597902B7A60836B63F084d9aC5a657cd](https://sepolia.basescan.org/address/0x90f1bc9C597902B7A60836B63F084d9aC5a657cd) |
| NullifierRegistry | [0xfE9a7603641e5Ac1cc155C62bAA7242dABf93B5a](https://sepolia.basescan.org/address/0xfE9a7603641e5Ac1cc155C62bAA7242dABf93B5a) |
| TossBankReclaimVerifierV2 | [0x08A773D828Ae1195FE7355e8885bD47456815da1](https://sepolia.basescan.org/address/0x08A773D828Ae1195FE7355e8885bD47456815da1) |
| USDC | [0x72f91969485c7efa53990fb0763ffa57ba73f3be](https://sepolia.basescan.org/address/0x72f91969485c7efa53990fb0763ffa57ba73f3be) |

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

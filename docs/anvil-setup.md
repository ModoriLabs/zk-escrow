# Anvil Test Setup

This guide shows how to run your test contracts on a local Anvil node.

## 🚀 Quick Start

### 1. Start Anvil Node

```bash
anvil --host 0.0.0.0 --port 8545
```

### 2. Deploy Test Contracts

This is the first private key in anvil's default accounts.

```bash
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/DeployTestSetup.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vv
```

### 3. Interact with Contracts

```bash
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/InteractWithDeployedContracts.sol --rpc-url http://127.0.0.1:8545 --broadcast -vv
```

## 📋 Deployed Contracts

| Contract | Address |
|----------|---------|
| MockUSDT | `0x5FbDB2315678afecb367f032d93F642f64180aa3` |
| NullifierRegistry | `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512` |
| ZkMinter | `0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0` |
| TossBankReclaimVerifier | `0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9` |

## 👥 Default Accounts

| Name | Address | Private Key |
|------|---------|-------------|
| Owner | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` |
| Alice | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` |
| Bob | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` | `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a` |

## 🔧 Setup Details

The deployment script mirrors your `BaseTest.sol` setup:

1. **MockUSDT**: ERC20 token for testing
2. **NullifierRegistry**: Manages nullifiers with owner having write permissions
3. **ZkMinter**: Main minting contract with owner permissions
4. **TossBankReclaimVerifier**: Payment verifier with configured witnesses

### Key Configurations

- **Owner**: Has all admin permissions
- **Timestamp Buffer**: 60 seconds
- **Witness Data**: Single witness address (`0x189027e3c77b3a92fd01bf7cc4e6a86e77f5034e`)
- **Verifier Permissions**: TossBankReclaimVerifier can write to NullifierRegistry

## 🧪 Testing with Cast

You can also interact with the contracts using `cast`:

```bash
# Check USDT balance
cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "balanceOf(address)(uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://127.0.0.1:8545

# Check if address is a writer in nullifier registry
cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "isWriter(address)(bool)" 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 --rpc-url http://127.0.0.1:8545

# Signal an intent
cast send 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 "signalIntent(address,uint256,address)" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 1000000000000000000000 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --rpc-url http://127.0.0.1:8545
```

## 🔍 Debugging

- **Anvil Logs**: Check the Anvil terminal for transaction logs
- **Verbose Deployment**: Use `-vvvv` flag for detailed logs
- **Contract Verification**: All contracts are deployed and configured as in your tests

## 📝 Notes

- Anvil resets on restart, so you'll need to redeploy contracts
- Use different private keys for different test scenarios
- The setup matches your `BaseTest.sol` exactly for consistency

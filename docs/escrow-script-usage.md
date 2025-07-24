# Escrow Script Usage Guide

This guide explains how to use the Escrow script (`script/Escrow.s.sol`) to interact with the Escrow contract.

## Prerequisites

1. Deploy the contracts first using:
   ```bash
   forge script script/deploy/DeployEscrowTestSetup.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
   ```

2. Set environment variables (or use defaults):
   ```bash
   export ESCROW_ADDRESS=0x24a7fb55e4AC2Cb40944bC560423B496DfA8803F
   export USDT_ADDRESS=0xC10B6DAFE4D7F7c693F44C51E716166B599644Ba
   export VERIFIER_ADDRESS=0x3F0c3E32bB166901AcD0Abc9452a3f0c5b8B2C9D
   export PRIVATE_KEY=<your-private-key>
   ```

## Available Functions

### 1. Check Deployment Status

Verify that all contracts are deployed and check your USDT balance:

```bash
forge script script/Escrow.s.sol --sig "checkDeployments()" --rpc-url http://127.0.0.1:8545
```

### 2. Create Deposit

Create a new deposit with custom parameters:

```bash
forge script script/Escrow.s.sol \
  --sig "createDeposit(uint256,uint256,uint256,string)" \
  10000000000 \
  100000000 \
  2000000000 \
  "100202642943(토스뱅크)" \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

Parameters:
- `amount`: Total deposit amount (in USDT smallest unit, 1 USDT = 1e6)
- `minIntent`: Minimum intent amount
- `maxIntent`: Maximum intent amount
- `payeeDetails`: Bank account or payment details

Or use the default deposit (10,000 USDT):

```bash
forge script script/Escrow.s.sol --sig "createDefaultDeposit()" --rpc-url http://127.0.0.1:8545 --broadcast
```

### 3. Signal Intent

Signal intent to purchase from a deposit:

```bash
forge script script/Escrow.s.sol \
  --sig "signalIntent(uint256,uint256,address,bytes32)" \
  1 \
  500000000 \
  0xYourAddress \
  0xc4ae21aac0c6549d71dd96035b7e0bdb6c79ebdba8891b666115bc976d16a29e \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

Parameters:
- `depositId`: ID of the deposit
- `amount`: Intent amount (500 USDT = 500000000)
- `to`: Recipient address
- `currency`: Currency code hash (USD = `0xc4ae21aac0c6549d71dd96035b7e0bdb6c79ebdba8891b666115bc976d16a29e`)

Or use the default intent for a deposit:

```bash
forge script script/Escrow.s.sol --sig "signalDefaultIntent(uint256)" 1 --rpc-url http://127.0.0.1:8545 --broadcast
```

### 4. Fulfill Intent

Fulfill an intent with payment proof:

```bash
forge script script/Escrow.s.sol \
  --sig "fulfillIntent(bytes,uint256)" \
  0xYourPaymentProof \
  1 \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

Parameters:
- `paymentProof`: Encoded payment proof from the verifier
- `intentId`: ID of the intent to fulfill

### 5. Cancel Intent

Cancel an existing intent:

```bash
forge script script/Escrow.s.sol \
  --sig "cancelIntent(uint256)" \
  1 \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

Parameters:
- `intentId`: ID of the intent to cancel

### 6. View Functions

View deposit details:

```bash
forge script script/Escrow.s.sol --sig "viewDeposit(uint256)" 1 --rpc-url http://127.0.0.1:8545
```

View intent details:

```bash
forge script script/Escrow.s.sol --sig "viewIntent(uint256)" 1 --rpc-url http://127.0.0.1:8545
```

## Common Workflows

### Complete Flow Example

1. **Deploy contracts** (if not already deployed):
   ```bash
   forge script script/deploy/DeployEscrowTestSetup.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
   ```

2. **Check deployment status**:
   ```bash
   forge script script/Escrow.s.sol --sig "checkDeployments()" --rpc-url http://127.0.0.1:8545
   ```

3. **Create a deposit**:
   ```bash
   forge script script/Escrow.s.sol --sig "createDefaultDeposit()" --rpc-url http://127.0.0.1:8545 --broadcast
   ```

4. **View the deposit**:
   ```bash
   forge script script/Escrow.s.sol --sig "viewDeposit(uint256)" 1 --rpc-url http://127.0.0.1:8545
   ```

5. **Signal an intent** (from a different account):
   ```bash
   export PRIVATE_KEY=<different-private-key>
   forge script script/Escrow.s.sol --sig "signalDefaultIntent(uint256)" 1 --rpc-url http://127.0.0.1:8545 --broadcast
   ```

6. **View the intent**:
   ```bash
   forge script script/Escrow.s.sol --sig "viewIntent(uint256)" 1 --rpc-url http://127.0.0.1:8545
   ```

## Currency Code Hashes

Common currency codes for the `signalIntent` function:
- USD: `0xc4ae21aac0c6549d71dd96035b7e0bdb6c79ebdba8891b666115bc976d16a29e`
- KRW: `0xe7ea93336602d83ab88b57e21095a1bb07fc4f31bf8fa7c86d892ecf00b267c3`

To calculate for other currencies:
```bash
cast keccak "EUR"
```

## Troubleshooting

1. **"Contract not deployed" errors**: Run the deployment script first
2. **"Insufficient USDT balance"**: The account needs USDT tokens. Check balance with `checkDeployments()`
3. **"Invalid intent amount"**: Ensure the amount is within the deposit's min/max range
4. **Gas errors**: Ensure the account has enough ETH for gas fees

## Amount Conversions

USDT uses 6 decimals:
- 1 USDT = 1,000,000 (1e6)
- 100 USDT = 100,000,000 (100e6)
- 1,000 USDT = 1,000,000,000 (1000e6)
- 10,000 USDT = 10,000,000,000 (10000e6)
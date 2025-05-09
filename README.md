# Noir Hackathon Participation!

🧞‍♂️ **Genie** is a zk-TLS based on-ramp system that bridges Web2 payments (e.g. Binance) to on-chain assets.

- [`legacy-web-prover`](https://github.com/elysia-dev/pluto-legacy-web-prover): ZK-TLS proof generation via HTTPS traffic interception.
- [`‍️noir-web-prover-circuits`](https://github.com/elysia-dev/noir-web-prover-circuits): Core ZK circuits implemented in Noir (ChaCha20, HTTP, JSON, etc).
- [`‍️zk-vault`](https://github.com/elysia-dev/zk-vault): Smart contract logic of `enroll` and `claim` for on-chain USDT distribution.

## Genie Vault Contract

This repository contains the smart contract logic for **Genie**, a zk-TLS-powered Web2 → Web3 on-ramp service.

The `Vault` contract verifies zk-TLS proof-backed Binance USDT payments and transfers equivalent USDT tokens on-chain to the specified recipient.

---

### 📦 Overview

In the Genie system:
Alice want to onRamp via (Binance -> Soneium L2 Blockchain)

1. Alice enrolls her on-ramp intent on-chain via the Genie Vault contract, submitting her Binance UID and recipient address.
2. Alice sends USDT to the designated Binance vault account.
3. Any user (e.g., a market maker) monitors public enrollments and checks Binance history.
4. That user generates a zk-TLS proof of Alice’s Binance payment, proving the USDT transfer without revealing sensitive data.
5. After verifying the proof, the server (or any prover) signs the (enrollId, amount) using the notary’s private key and calls claim().
6. The contract verifies the ECDSA signature and transfers USDT to Alice’s recipient address on Soneium L2.

---

### 🔐 Contract Features

- `enroll(orderId, binanceId, amount)`  
  Enrolls a USDT deposit claim based on Binance transfer metadata.

- `claim(orderId, recipient, amount, v, r, s)`  
  Verifies ECDSA signature by notary and transfers USDT.

- `updateNotary(newAddress)`  
  Allows notary rotation (can only be called by current notary).

- **Security**:
  - Prevents duplicate claims per enrollment.
  - Maximum allowed transfer is capped (e.g. 10 USDT) for current hack version.

---

### Scripts

```sh
# deploy contract
forge script script/DeployVault.sol --rpc-url minato --broadcast --private-key $PRIVATE_KEY

# verify contract
forge verify-contract \
  --rpc-url https://rpc.minato.soneium.org \
  --verifier blockscout \
  --verifier-url 'https://soneium-minato.blockscout.com/api/' \
  0xF3743092B82e074265093faE373b0F4e0f5444e9 \
  src/Vault.sol:Vault


# enroll
RECIPIENT_ADDRESS=0x3ACeFef486Ca88Cc44b68F029E57700bCFd531a4 AMOUNT=1e6 FROM_BINANCE_ID=93260646 forge script script/VaultScript.sol:Enroll --rpc-url minato --broadcast

# claim
RECIPIENT_ADDRESS=0x3ACeFef486Ca88Cc44b68F029E57700bCFd531a4 AMOUNT=1e6 forge script script/VaultScript.sol:Claim --rpc-url minato --broadcast

# USDT Transfer
forge script script/VaultScript.sol:TransferUSDTToVault --rpc-url minato --broadcast

# Check mock USDT balance
RECIPIENT_ADDRESS=0x3ACeFef486Ca88Cc44b68F029E57700bCFd531a4 forge script script/VaultScript.sol:CheckUSDTBalance --rpc-url minato --broadcast

# Clear
forge script script/VaultScript.sol:ClearEnrollments --rpc-url minato --broadcast
```

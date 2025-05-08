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

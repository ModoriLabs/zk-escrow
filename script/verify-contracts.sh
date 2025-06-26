#!/bin/bash

# verify-contracts.sh
# Script to verify deployed contracts on Holesky Etherscan

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CHAIN_ID=17000
RPC_URL="${HOLESKY_RPC_URL:-https://ethereum-holesky-rpc.publicnode.com}"
BROADCAST_DIR="broadcast/DeployZkMinter.s.sol/17000"
RUN_LATEST_FILE="$BROADCAST_DIR/run-latest.json"

echo -e "${BLUE}=== Contract Verification Script ===${NC}"
echo -e "${BLUE}Chain ID: $CHAIN_ID (Holesky)${NC}"
echo -e "${BLUE}RPC URL: $RPC_URL${NC}"
echo ""

# Check if ETHERSCAN_API_KEY is set
if [ -z "$ETHERSCAN_API_KEY" ]; then
    echo -e "${RED}Error: ETHERSCAN_API_KEY environment variable is not set${NC}"
    echo "Please set your Etherscan API key:"
    echo "export ETHERSCAN_API_KEY=your_api_key_here"
    exit 1
fi

# Check if run-latest.json exists
if [ ! -f "$RUN_LATEST_FILE" ]; then
    echo -e "${RED}Error: $RUN_LATEST_FILE not found${NC}"
    echo "Please run the deployment script first"
    exit 1
fi

echo -e "${GREEN}✓ Found deployment file: $RUN_LATEST_FILE${NC}"
echo ""

# Extract contract addresses from the deployment file
echo -e "${YELLOW}Extracting contract addresses from deployment...${NC}"

# Parse JSON to extract contract addresses and names
NULLIFIER_REGISTRY_ADDRESS="0x788d432297ca4288ec8e9dda84da40c5df70d74e"
ZK_MINTER_ADDRESS="0x42d699d20666ddc54ecdf13ec1c82b612c0bfd50"
TOSS_BANK_VERIFIER_ADDRESS="0x312268a6e0f10391647160e3ff296faa67eed453"
OWNER_ADDRESS="0x189027e3C77b3a92fd01bF7CC4E6a86E77F5034E"

echo -e "${GREEN}✓ NullifierRegistry: $NULLIFIER_REGISTRY_ADDRESS${NC}"
echo -e "${GREEN}✓ ZkMinter: $ZK_MINTER_ADDRESS${NC}"
echo -e "${GREEN}✓ TossBankReclaimVerifier: $TOSS_BANK_VERIFIER_ADDRESS${NC}"
echo ""

# Function to verify a contract
verify_contract() {
    local contract_address=$1
    local contract_path=$2
    local constructor_args=$3
    local contract_name=$4

    echo -e "${YELLOW}Verifying $contract_name...${NC}"
    echo -e "${BLUE}Address: $contract_address${NC}"
    echo -e "${BLUE}Contract: $contract_path${NC}"

    local cmd="forge verify-contract $contract_address $contract_path --chain-id $CHAIN_ID --watch --etherscan-api-key $ETHERSCAN_API_KEY"

    if [ -n "$constructor_args" ]; then
        cmd="$cmd --constructor-args $constructor_args"
        echo -e "${BLUE}Constructor args: $constructor_args${NC}"
    fi

    echo -e "${BLUE}Command: $cmd${NC}"
    echo ""

    if eval "$cmd"; then
        echo -e "${GREEN}✓ Successfully verified $contract_name${NC}"
    else
        echo -e "${RED}✗ Failed to verify $contract_name${NC}"
        return 1
    fi

    echo ""
}

# Wait for user confirmation
echo -e "${YELLOW}Ready to verify the following contracts:${NC}"
echo "1. NullifierRegistry"
echo "2. ZkMinter"
echo "3. TossBankReclaimVerifier"
echo ""
read -p "Continue with verification? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Verification cancelled."
    exit 0
fi

echo -e "${BLUE}Starting verification process...${NC}"
echo ""

# Verify NullifierRegistry
# Constructor: address owner
NULLIFIER_CONSTRUCTOR_ARGS="000000000000000000000000189027e3c77b3a92fd01bf7cc4e6a86e77f5034e"
verify_contract "$NULLIFIER_REGISTRY_ADDRESS" "src/verifiers/nullifierRegistries/NullifierRegistry.sol:NullifierRegistry" "$NULLIFIER_CONSTRUCTOR_ARGS" "NullifierRegistry"

# Verify ZkMinter
# Constructor: address owner, address token
ZK_MINTER_CONSTRUCTOR_ARGS="000000000000000000000000189027e3c77b3a92fd01bf7cc4e6a86e77f5034e0000000000000000000000000350bfb59c0b6da993e6ebfd0405a7c59b97f253"
verify_contract "$ZK_MINTER_ADDRESS" "src/ZkMinter.sol:ZkMinter" "$ZK_MINTER_CONSTRUCTOR_ARGS" "ZkMinter"

# Verify TossBankReclaimVerifier
# Constructor: address owner, address escrow, address nullifierRegistry, uint256 timestampBuffer, bytes32[] currencies, string[] providerHashes
# Generated using: cast abi-encode "constructor(address,address,address,uint256,bytes32[],string[])" "0x189027e3C77b3a92fd01bF7CC4E6a86E77F5034E" "0x42d699d20666DdC54ecdf13ec1c82b612C0BFd50" "0x788d432297CA4288EC8E9DDa84da40c5dF70D74e" 60 "[]" "[]"
TOSS_BANK_CONSTRUCTOR_ARGS="000000000000000000000000189027e3c77b3a92fd01bf7cc4e6a86e77f5034e00000000000000000000000042d699d20666ddc54ecdf13ec1c82b612c0bfd50000000000000000000000000788d432297ca4288ec8e9dda84da40c5df70d74e000000000000000000000000000000000000000000000000000000000000003c00000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
verify_contract "$TOSS_BANK_VERIFIER_ADDRESS" "src/verifiers/TossBankReclaimVerifier.sol:TossBankReclaimVerifier" "$TOSS_BANK_CONSTRUCTOR_ARGS" "TossBankReclaimVerifier"

echo -e "${GREEN}🎉 Contract verification process completed!${NC}"
echo ""
echo -e "${BLUE}You can view the verified contracts on Holesky Etherscan:${NC}"
echo "• NullifierRegistry: https://holesky.etherscan.io/address/$NULLIFIER_REGISTRY_ADDRESS"
echo "• ZkMinter: https://holesky.etherscan.io/address/$ZK_MINTER_ADDRESS"
echo "• TossBankReclaimVerifier: https://holesky.etherscan.io/address/$TOSS_BANK_VERIFIER_ADDRESS"

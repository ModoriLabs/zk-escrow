#!/usr/bin/env bash

# Usage: ./scripts/print-deployments.sh <chainId>
CHAIN_ID=$1
if [ -z "$CHAIN_ID" ]; then
  echo "Usage: ./scripts/print-deployments.sh <chainId>"
  exit 1
fi

DEPLOYMENT_FILE="deployments/${CHAIN_ID}-deploy.json"

if [ ! -f "$DEPLOYMENT_FILE" ]; then
  echo "Deployment file not found: $DEPLOYMENT_FILE"
  exit 1
fi

# Determine explorer URL based on chain ID
if [ "$CHAIN_ID" == "1" ]; then
  EXPLORER="https://etherscan.io/address/"
elif [ "$CHAIN_ID" == "17000" ]; then
  EXPLORER="https://holesky.etherscan.io/address/"
elif [ "$CHAIN_ID" == "84532" ]; then
  EXPLORER="https://sepolia.basescan.org/address/"
elif [ "$CHAIN_ID" == "8453" ]; then
  EXPLORER="https://basescan.org/address/"
elif [ "$CHAIN_ID" == "31337" ]; then
  EXPLORER=""  # localhost has no explorer
else
  echo "Chain ID $CHAIN_ID not recognized. Using empty explorer URL."
  EXPLORER=""
fi

echo '| Contracts                    | Address                                                                                                                  |'
echo '|------------------------------|--------------------------------------------------------------------------------------------------------------------------|'

# Process the deployment JSON file
jq -r "to_entries[] | [.key, .value] | @tsv" "$DEPLOYMENT_FILE" | while read -r key value; do
  if [[ "$EXPLORER" != "" ]]; then
    echo "| $key | [$value]($EXPLORER$value) |"
  else
    echo "| $key | $value |"
  fi
done

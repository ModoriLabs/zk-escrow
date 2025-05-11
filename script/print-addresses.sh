#!/usr/bin/env bash

# Usage: ./scripts/print-addresses.sh <network>
NETWORK=$1
if [ -z "$NETWORK" ]; then
  echo "Usage: ./scripts/print-addresses.sh <network>"
  exit 1
fi

if [ "$NETWORK" == "sepolia" ]; then
  EXPLORER="https://sepolia.etherscan.io/address/"
elif [ "$NETWORK" == "soneium" ]; then
  EXPLORER="https://soneium.blockscout.com/address/"
elif [ "$NETWORK" == "minato" ]; then
  EXPLORER="https://explorer-testnet.soneium.org/address/"
elif [ "$NETWORK" == "localhost" ]; then
  EXPLORER=""
else
  echo "Invalid network: $NETWORK"
  exit 1
fi

yarn hardhat export --network $NETWORK --export temp.json
echo '| Contracts                    | Address                                                                                                                  |'
echo '|------------------------------|--------------------------------------------------------------------------------------------------------------------------|'
jq -r ".contracts | to_entries[] | [.key, \"[\(.value.address)]($EXPLORER\(.value.address))\"] | @tsv" temp.json \
  | sed 's/\t/ | /g; s/^/| /; s/$/ |/' \
  | awk '!(/Implementation/ || /Proxy/)'

rm temp.json

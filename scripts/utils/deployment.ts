/**
 * Get chain name for Escrow based on chain ID
 */
export function getChainNameForEscrow(chainId: number): string {
  const chainNames: { [key: number]: string } = {
    31337: "anvil",
    84532: "basesep",
    8453: "base",
    1001: "kairos",
    8217: "kaia",
  };
  return chainNames[chainId] || "unknown";
}

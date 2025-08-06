// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "script/BaseVerifyScript.s.sol";

/*
Usage Examples:

# Verify Escrow contract on Base Sepolia
forge script script/VerifyEscrow.s.sol \
  --rpc-url base_sepolia --broadcast --private-key $TESTNET_PRIVATE_KEY

# Verify all contracts on Holesky
forge script script/VerifyEscrow.s.sol \
  --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY \
  --sig "verifyAll()"

# Verify specific contract
forge script script/VerifyEscrow.s.sol \
  --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY \
  --sig "verifyMockUSDT()"

Note:
- Contract addresses are automatically loaded from deployments/{chainId}-deploy.json
- Requires ETHERSCAN_API_KEY environment variable to be set
- Enable FFI in foundry.toml: ffi = true
*/

contract VerifyEscrow is BaseVerifyScript {
    function run() external {
        verifyEscrow();
    }

    function verifyAll() external {
        uint256 chainId = block.chainid;
        console.log("Chain ID:", chainId);
        console.log("=== VERIFYING ALL CONTRACTS ===");

        verifyEscrow();
        verifyMockUSDT();
        verifyNullifierRegistry();
        verifyTossBankReclaimVerifierV2();

        console.log("=== VERIFICATION COMPLETED ===");
    }

    function verifyEscrow() public {
        uint256 chainId = block.chainid;
        console.log("Chain ID:", chainId);
        console.log("Verifying contracts on chain:", chainId);

        // Get deployed Escrow address
        address escrowAddress = _getDeployedAddress("Escrow");
        require(escrowAddress != address(0), "Escrow not deployed");

        console.log("=== VERIFYING ESCROW CONTRACT ===");
        _verifyEscrow(escrowAddress, chainId);
        console.log("=== ESCROW VERIFICATION COMPLETED ===");
    }

    function verifyMockUSDT() public {
        address mockUSDTAddress = _getDeployedAddress("MockUSDT");
        require(mockUSDTAddress != address(0), "MockUSDT not deployed");

        console.log("=== VERIFYING MOCKUSDT CONTRACT ===");
        _verifyMockUSDT(mockUSDTAddress);
        console.log("=== MOCKUSDT VERIFICATION COMPLETED ===");
    }

    function verifyNullifierRegistry() public {
        address nullifierRegistryAddress = _getDeployedAddress("NullifierRegistry");
        require(nullifierRegistryAddress != address(0), "NullifierRegistry not deployed");

        console.log("=== VERIFYING NULLIFIER REGISTRY CONTRACT ===");
        _verifyNullifierRegistry(nullifierRegistryAddress);
        console.log("=== NULLIFIER REGISTRY VERIFICATION COMPLETED ===");
    }

    function verifyTossBankReclaimVerifierV2() public {
        address verifierAddress = _getDeployedAddress("TossBankReclaimVerifierV2");
        require(verifierAddress != address(0), "TossBankReclaimVerifierV2 not deployed");

        console.log("=== VERIFYING TOSSBANK RECLAIM VERIFIER V2 CONTRACT ===");
        _verifyTossBankReclaimVerifierV2(verifierAddress);
        console.log("=== TOSSBANK RECLAIM VERIFIER V2 VERIFICATION COMPLETED ===");
    }

    function _verifyEscrow(address escrowAddress, uint256 chainId) internal {
        // Prepare constructor arguments based on Escrow constructor
        // Constructor: Escrow(address _owner, uint256 _intentExpirationPeriod, string memory _chainName)
        address owner = broadcaster;
        uint256 intentExpirationPeriod = 1800; // 30 minutes default
        string memory chainName = _getChainName(chainId);

        bytes memory constructorArgs = abi.encode(owner, intentExpirationPeriod, chainName);

        _executeVerification(escrowAddress, "src/Escrow.sol:Escrow", constructorArgs, "Escrow");
    }

    function _verifyMockUSDT(address mockUSDTAddress) internal {
        // Constructor: MockUSDT(address _owner)
        address owner = broadcaster;

        bytes memory constructorArgs = abi.encode(owner);

        _executeVerification(mockUSDTAddress, "src/MockUSDT.sol:MockUSDT", constructorArgs, "MockUSDT");
    }

    function _verifyNullifierRegistry(address nullifierRegistryAddress) internal {
        // Constructor: NullifierRegistry(address _owner)
        address owner = broadcaster;

        bytes memory constructorArgs = abi.encode(owner);

        _executeVerification(
            nullifierRegistryAddress,
            "src/verifiers/nullifierRegistries/NullifierRegistry.sol:NullifierRegistry",
            constructorArgs,
            "NullifierRegistry"
        );
    }

    function _verifyTossBankReclaimVerifierV2(address verifierAddress) internal {
        // Constructor: TossBankReclaimVerifierV2(address _owner, address _escrow, INullifierRegistry
        // _nullifierRegistry, uint256 _timestampBuffer, bytes32[] memory _currencies, string[] memory _providerHashes)
        address owner = broadcaster;
        address escrowAddress = _getDeployedAddress("Escrow");
        address nullifierRegistryAddress = _getDeployedAddress("NullifierRegistry");
        uint256 timestampBuffer = 60;

        // Prepare currencies array
        bytes32[] memory currencies = new bytes32[](1);
        currencies[0] = keccak256("KRW");

        // Prepare provider hashes array
        string[] memory providerHashes = new string[](1);
        providerHashes[0] = "0xffb501528259e6d684e1c2153fbbacab453fe9c97c336dc4f8f48d70a0e2a13d";

        bytes memory constructorArgs =
            abi.encode(owner, escrowAddress, nullifierRegistryAddress, timestampBuffer, currencies, providerHashes);

        _executeVerification(
            verifierAddress,
            "src/verifiers/TossBankReclaimVerifierV2.sol:TossBankReclaimVerifierV2",
            constructorArgs,
            "TossBankReclaimVerifierV2"
        );
    }
}

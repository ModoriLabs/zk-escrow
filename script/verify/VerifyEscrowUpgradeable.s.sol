// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "script/BaseVerifyScript.s.sol";

/*
Usage Examples:

# Verify EscrowUpgradeable contracts on Base Sepolia
forge script script/verify/VerifyEscrowUpgradeable.s.sol \
  --rpc-url base_sepolia --broadcast --private-key $TESTNET_PRIVATE_KEY

# Verify all contracts on Holesky
forge script script/verify/VerifyEscrowUpgradeable.s.sol \
  --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY \
  --sig "verifyAll()"

# Verify only the implementation contract
forge script script/verify/VerifyEscrowUpgradeable.s.sol \
  --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY \
  --sig "verifyImplementation()"

# Verify only the proxy contract
forge script script/verify/VerifyEscrowUpgradeable.s.sol \
  --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY \
  --sig "verifyProxy()"

Note:
- Contract addresses are automatically loaded from deployments/{chainId}-deploy.json
- Requires ETHERSCAN_API_KEY environment variable to be set
- Enable FFI in foundry.toml: ffi = true
- For upgradeable contracts, both proxy and implementation need verification
*/

contract VerifyEscrowUpgradeable is BaseVerifyScript {
    function run() external {
        verifyEscrowUpgradeable();
    }

    function verifyAll() external {
        uint256 chainId = block.chainid;
        console.log("Chain ID:", chainId);
        console.log("=== VERIFYING ALL ESCROW UPGRADEABLE CONTRACTS ===");

        verifyEscrowUpgradeable();
        verifyMockUSDT();
        verifyNullifierRegistry();
        verifyTossBankReclaimVerifierV2();

        console.log("=== VERIFICATION COMPLETED ===");
    }

    function verifyEscrowUpgradeable() public {
        console.log("=== VERIFYING ESCROW UPGRADEABLE CONTRACTS ===");

        verifyImplementation();
        verifyProxy();

        console.log("=== ESCROW UPGRADEABLE VERIFICATION COMPLETED ===");
    }

    function verifyImplementation() public {
        address implementationAddress = _getDeployedAddress("EscrowImplementation");
        require(implementationAddress != address(0), "EscrowImplementation not deployed");

        console.log("=== VERIFYING ESCROW IMPLEMENTATION CONTRACT ===");
        _verifyEscrowImplementation(implementationAddress);
        console.log("=== ESCROW IMPLEMENTATION VERIFICATION COMPLETED ===");
    }

    function verifyProxy() public {
        address proxyAddress = _getDeployedAddress("EscrowProxy");
        require(proxyAddress != address(0), "EscrowProxy not deployed");

        console.log("=== VERIFYING ESCROW PROXY CONTRACT ===");
        _verifyEscrowProxy(proxyAddress);
        console.log("=== ESCROW PROXY VERIFICATION COMPLETED ===");
    }

    function verifyMockUSDT() public {
        address mockUSDTAddress = _getDeployedAddress("USDC");
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

    function _verifyEscrowImplementation(address implementationAddress) internal {
        // EscrowUpgradeable implementation constructor has no arguments
        // The constructor only calls _disableInitializers() from OpenZeppelin
        bytes memory constructorArgs = abi.encode();

        _executeVerification(
            implementationAddress,
            "src/EscrowUpgradeable.sol:EscrowUpgradeable",
            constructorArgs,
            "EscrowUpgradeable Implementation"
        );
    }

    function _verifyEscrowProxy(address proxyAddress) internal {
        uint256 chainId = block.chainid;

        // Get the implementation address used during deployment
        address implementationAddress = _getDeployedAddress("EscrowImplementation");
        require(implementationAddress != address(0), "Implementation address not found");

        // Prepare initialization data for the proxy
        // This should match what was used during deployment
        address owner = broadcaster; // Assuming broadcaster is the owner
        uint256 intentExpirationPeriod = 1800; // 30 minutes default
        string memory chainName = _getChainName(chainId);

        bytes memory initData =
            abi.encodeWithSignature("initialize(address,uint256,string)", owner, intentExpirationPeriod, chainName);

        // ERC1967Proxy constructor: ERC1967Proxy(address implementation, bytes memory _data)
        bytes memory constructorArgs = abi.encode(implementationAddress, initData);

        _executeVerification(
            proxyAddress,
            "node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
            constructorArgs,
            "EscrowUpgradeable Proxy"
        );
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
        address escrowAddress = _getDeployedAddress("EscrowProxy"); // Use proxy address for upgradeable escrow
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

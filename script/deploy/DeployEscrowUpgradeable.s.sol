// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EscrowUpgradeable} from "src/EscrowUpgradeable.sol";
import {TossBankReclaimVerifierV2} from "src/verifiers/TossBankReclaimVerifierV2.sol";
import {NullifierRegistry} from "src/verifiers/nullifierRegistries/NullifierRegistry.sol";
import {INullifierRegistry} from "src/verifiers/nullifierRegistries/INullifierRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "script/Base.s.sol";

contract DeployEscrowUpgradeable is BaseScript {
    uint256 public constant INTENT_EXPIRATION_PERIOD = 1800; // 30 minutes
    string public constant PROVIDER_HASH = "0xffb501528259e6d684e1c2153fbbacab453fe9c97c336dc4f8f48d70a0e2a13d";

    EscrowUpgradeable public escrowImplementation;
    EscrowUpgradeable public escrow;
    TossBankReclaimVerifierV2 public tossBankReclaimVerifierV2;
    NullifierRegistry public nullifierRegistry;

    function run() external {
        vm.startBroadcast();
        address owner = broadcaster;
        string memory chainName = _getChainNameForEscrow(block.chainid);

        // Check if NullifierRegistry already exists
        address existingNullifierRegistry = _getDeployedAddress("NullifierRegistry");
        if (existingNullifierRegistry != address(0)) {
            nullifierRegistry = NullifierRegistry(existingNullifierRegistry);
            console.log("Using existing NullifierRegistry at:", address(nullifierRegistry));
        } else {
            // Deploy new NullifierRegistry if not found
            nullifierRegistry = new NullifierRegistry(owner);
            console.log("NullifierRegistry deployed at:", address(nullifierRegistry));

            // Update deployment file
            _updateDeploymentFile("NullifierRegistry", address(nullifierRegistry));
        }

        address prevEscrowProxy = _getDeployedAddress("EscrowProxy");
        if (prevEscrowProxy != address(0)) {
            escrow = EscrowUpgradeable(prevEscrowProxy);
            console.log("Escrow proxy already deployed at:", prevEscrowProxy);
        } else {
            // Deploy implementation
            escrowImplementation = new EscrowUpgradeable();
            console.log("Escrow implementation deployed at:", address(escrowImplementation));
            _updateDeploymentFile("EscrowImplementation", address(escrowImplementation));
            
            // Deploy proxy and initialize
            bytes memory initData = abi.encodeWithSelector(
                EscrowUpgradeable.initialize.selector,
                owner,
                INTENT_EXPIRATION_PERIOD,
                chainName
            );
            
            ERC1967Proxy proxy = new ERC1967Proxy(
                address(escrowImplementation),
                initData
            );
            
            escrow = EscrowUpgradeable(address(proxy));
            console.log("Escrow proxy deployed at:", address(escrow));
            _updateDeploymentFile("EscrowProxy", address(escrow));
            _updateDeploymentFile("Escrow", address(escrow)); // Keep backward compatibility
        }

        // Check if TossBankReclaimVerifierV2 already exists
        address existingTossBankReclaimVerifierV2 = _getDeployedAddress("TossBankReclaimVerifierV2");
        if (existingTossBankReclaimVerifierV2 != address(0)) {
            tossBankReclaimVerifierV2 = TossBankReclaimVerifierV2(existingTossBankReclaimVerifierV2);
            console.log("Using existing TossBankReclaimVerifierV2 at:", address(tossBankReclaimVerifierV2));
        } else {
            console.log("Deploying new TossBankReclaimVerifierV2");
            // Deploy new TossBankReclaimVerifierV2 if not found
            string[] memory providerHashes = new string[](1);
            providerHashes[0] = PROVIDER_HASH;
            bytes32[] memory verifierCurrencies = new bytes32[](1);
            verifierCurrencies[0] = keccak256("KRW");
            tossBankReclaimVerifierV2 = new TossBankReclaimVerifierV2(
                owner,
                address(escrow),
                INullifierRegistry(address(nullifierRegistry)),
                INTENT_EXPIRATION_PERIOD,
                verifierCurrencies,
                providerHashes
            );
            _updateDeploymentFile("TossBankReclaimVerifierV2", address(tossBankReclaimVerifierV2));
        }

        // Give write permission to verifier
        // nullifierRegistry.addWritePermission(address(tossBankReclaimVerifierV2));
        console.log("Added write permission to TossBankReclaimVerifier");

        escrow.addWhitelistedPaymentVerifier(address(tossBankReclaimVerifierV2));
        console.log("Added whitelisted payment verifier to Escrow");

        // addEscrow is done in the constructor of TossBankReclaimVerifierV2
        if (!tossBankReclaimVerifierV2.isEscrow(address(escrow))) {
            tossBankReclaimVerifierV2.addEscrow(address(escrow));
            console.log("Added escrow to TossBankReclaimVerifierV2");
        }
        vm.stopBroadcast();

        // Log final addresses
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Escrow Proxy:", address(escrow));
        console.log("Escrow Implementation:", address(escrowImplementation != EscrowUpgradeable(address(0)) ? escrowImplementation : EscrowUpgradeable(address(0))));
        console.log("TossBankReclaimVerifierV2:", address(tossBankReclaimVerifierV2));
        console.log("NullifierRegistry:", address(nullifierRegistry));
        console.log("========================\n");
    }
}
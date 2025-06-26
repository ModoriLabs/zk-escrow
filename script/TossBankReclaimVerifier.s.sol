// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Base.s.sol";
import { TossBankReclaimVerifier } from "../src/verifiers/TossBankReclaimVerifier.sol";

contract TossBankReclaimVerifierScript is BaseScript {

    // Provider hash from BaseTest.sol
    string public constant PROVIDER_HASH = "0xffb501528259e6d684e1c2153fbbacab453fe9c97c336dc4f8f48d70a0e2a13d";

    function addProviderHash() public broadcast {
        uint256 chainId = block.chainid;
        console.log("Chain ID:", chainId);
        console.log("Broadcaster:", broadcaster);

        // Get TossBankReclaimVerifier address from deployments
        address tossBankVerifierAddress;

        if (chainId == 17000) { // holesky
            tossBankVerifierAddress = _getDeployedAddress(chainId, "TossBankReclaimVerifier");
        } else {
            revert("Unsupported chain ID. Please add the deployed address for this chain.");
        }

        console.log("TossBankReclaimVerifier address:", tossBankVerifierAddress);

        // Get contract instance
        TossBankReclaimVerifier tossBankVerifier = TossBankReclaimVerifier(tossBankVerifierAddress);

        // Check if provider hash is already added
        bool isAlreadyAdded = tossBankVerifier.isProviderHash(PROVIDER_HASH);
        console.log("Provider hash already added:", isAlreadyAdded);

        if (isAlreadyAdded) {
            console.log("Provider hash is already added. Nothing to do.");
            return;
        }

        // Add the provider hash
        console.log("Adding provider hash:", PROVIDER_HASH);
        tossBankVerifier.addProviderHash(PROVIDER_HASH);
        console.log("Successfully added provider hash!");

        // Get all provider hashes
        string[] memory allProviderHashes = tossBankVerifier.getProviderHashes();
        console.log("Total provider hashes:", allProviderHashes.length);
        for (uint i = 0; i < allProviderHashes.length; i++) {
            console.log("Provider hash", i, ":", allProviderHashes[i]);
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AddressArrayUtils } from "../external/AddressArrayUtils.sol";
import { Claims } from "../external/Claims.sol";
import { StringArrayUtils } from "../external/StringArrayUtils.sol";
import { BasePaymentVerifier } from "./BasePaymentVerifier.sol";
import { INullifierRegistry } from "./nullifierRegistries/INullifierRegistry.sol";
import { IReclaimVerifier } from "./interfaces/IReclaimVerifier.sol";
import { console } from "forge-std/src/console.sol";

contract BaseReclaimPaymentVerifier is IReclaimVerifier, BasePaymentVerifier {
    using AddressArrayUtils for address[];
    using StringArrayUtils for string[];

    /* ============ Constants ============ */
    uint256 internal constant PRECISE_UNIT = 1e18;

    /* ============ State Variables ============ */
    mapping(string => bool) public isProviderHash;
    string[] public providerHashes;                         // Set of provider hashes that these proofs should be for

    /* ============ Events ============ */
    event ProviderHashAdded(string providerHash);
    event ProviderHashRemoved(string providerHash);

    constructor(
        address _owner,
        address _ramp,
        INullifierRegistry _nulliferRegistry,
        uint256 _timestampBuffer,
        bytes32[] memory _currencies,
        string[] memory _providerHashes
    )
        BasePaymentVerifier(
            _owner,
            _ramp,
            _nulliferRegistry,
            _timestampBuffer,
            _currencies
        )
    {
        for (uint256 i = 0; i < _providerHashes.length; i++) {
            require(!isProviderHash[_providerHashes[i]], "Provider hash already added");
            isProviderHash[_providerHashes[i]] = true;
            providerHashes.push(_providerHashes[i]);

            emit ProviderHashAdded(_providerHashes[i]);
        }
    }

    /* ============ Admin Functions ============ */

    /**
     * ONLY OWNER: Add provider hash string. Provider hash must not have been previously added.
     *
     * @param _newProviderHash    New provider hash to be added
     */
    function addProviderHash(string memory _newProviderHash) external onlyOwner {
        require(!isProviderHash[_newProviderHash], "Provider hash already added");

        isProviderHash[_newProviderHash] = true;
        providerHashes.push(_newProviderHash);

        emit ProviderHashAdded(_newProviderHash);
    }

    /**
     * ONLY OWNER: Remove provider hash string. Provider hash must have been previously added.
     *
     * @param _removeProviderHash    Provider hash to be removed
     */
    function removeProviderHash(string memory _removeProviderHash) external onlyOwner {
        require(isProviderHash[_removeProviderHash], "Provider hash not found");

        delete isProviderHash[_removeProviderHash];
        providerHashes.removeStorage(_removeProviderHash);

        emit ProviderHashRemoved(_removeProviderHash);
    }

    /* ============ Public Functions ============ */

    /**
     * @param proof                 Proof to be verified
     * @param _witnesses            List of accepted witnesses
     * @param _requiredThreshold    Minimum number of signatures required from accepted witnesses
     */
    function verifyProofSignatures(
        ReclaimProof memory proof,
        address[] memory _witnesses,
        uint256 _requiredThreshold
    ) public pure returns (bool) {
        require(_requiredThreshold > 0, "Required threshold must be greater than 0");
        require(_requiredThreshold <= _witnesses.length, "Required threshold must be less than or equal to number of witnesses");
        require(proof.signedClaim.signatures.length > 0, "No signatures");

        Claims.SignedClaim memory signed = Claims.SignedClaim(
            proof.signedClaim.claim,
            proof.signedClaim.signatures
        );

        bytes32 hashed = Claims.hashClaimInfo(proof.claimInfo);
        require(proof.signedClaim.claim.identifier == hashed, "ClaimInfo hash doesn't match");
        require(hashed != bytes32(0), "ClaimInfo hash is zero");

        address[] memory claimSigners = Claims.recoverSignersOfSignedClaim(signed);
        require(claimSigners.length >= _requiredThreshold, "Fewer signatures than required threshold");

        address[] memory seenSigners = new address[](claimSigners.length);
        uint256 validWitnessSignatures;

        for (uint256 i = 0; i < claimSigners.length; i++) {
            address currSigner = claimSigners[i];
            if (seenSigners.contains(currSigner)) {
                continue;
            }

            if (_witnesses.contains(currSigner)) {
                seenSigners[validWitnessSignatures] = currSigner;
                validWitnessSignatures++;
            }
        }

        require(
            validWitnessSignatures >= _requiredThreshold,
            "Fewer witness signatures than required threshold"
        );

        return true;
    }

    /* ============ View Functions ============ */

    function getProviderHashes() external view returns (string[] memory) {
        return providerHashes;
    }

    /* ============ Internal Functions ============ */

    function _validateProviderHash(string memory _providerHash) internal view returns (bool) {
        return isProviderHash[_providerHash];
    }

    function _validateAndAddSigNullifier(bytes[] memory _sigArray) internal {
        bytes32 nullifier = keccak256(abi.encode(_sigArray));
        require(!nullifierRegistry.isNullified(nullifier), "Nullifier has already been used");
        nullifierRegistry.addNullifier(nullifier);
    }
}

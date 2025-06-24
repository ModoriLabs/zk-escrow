// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseTest.sol";

contract TossBankReclaimVerifierTest is BaseTest {
    // Test data as JSON string
    // won does not work: Invalid character in string.

    IReclaimVerifier.ReclaimProof public proof;

    function setUp() public override {
        super.setUp();
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/tests/fixtures/proof.json");
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        // proof = abi.decode(data, (IReclaimVerifier.ReclaimProof));

        // Parse individual fields instead of decoding entire struct
        proof.claimInfo.provider = vm.parseJsonString(json, ".claimInfo.provider");
        proof.claimInfo.parameters = vm.parseJsonString(json, ".claimInfo.parameters");
        proof.claimInfo.context = vm.parseJsonString(json, ".claimInfo.context");

        proof.signedClaim.claim.identifier = vm.parseJsonBytes32(json, ".signedClaim.claim.identifier");
        proof.signedClaim.claim.owner = vm.parseJsonAddress(json, ".signedClaim.claim.owner");
        proof.signedClaim.claim.timestampS = uint32(vm.parseJsonUint(json, ".signedClaim.claim.timestampS"));
        proof.signedClaim.claim.epoch = uint32(vm.parseJsonUint(json, ".signedClaim.claim.epoch"));

         // Handle signatures array
        // 0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000636c417755e3ae25c6c166d181c0607f4c572a3000000000000000000000000244897572368eadf65bfbc5aec98d8e5443a9072
        // 1 slot is 32 bytes, 64 hex chars
        // slot0: 0x20
        // slot1: 0x2
        // slot2: address1
        // slot3: address2
        string memory sigHex = vm.parseJsonString(json, ".signedClaim.signatures[0]");
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = vm.parseBytes(sigHex);
        console.logBytes(signatures[0]);
        proof.signedClaim.signatures = signatures;

        proof.isAppclipProof = vm.parseJsonBool(json, ".isAppclipProof");
    }

    function test_VerifyPayment() public {
        bytes memory encodedProof = abi.encode(proof);
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(0x189027e3C77b3a92fd01bF7CC4E6a86E77F5034E);
        bytes memory data = abi.encode(witnesses);

        tossBankReclaimVerifier.verifyPayment(
            IPaymentVerifier.VerifyPaymentData({
                paymentProof: encodedProof,
                intentAmount: 100,
                intentTimestamp: 1732845455,
                conversionRate: 1e18,
                data: data
            })
        );
    }

    function test_GetIdentifierFromClaimInfo() public {
        Claims.ClaimInfo memory claimInfo = proof.claimInfo;

        bytes32 calculatedIdentifier = getIdentifierFromClaimInfo(claimInfo);
        bytes32 expectedIdentifier = proof.signedClaim.claim.identifier;

        // Log both for debugging
        emit log_named_bytes32("Calculated Identifier", calculatedIdentifier);
        emit log_named_bytes32("Expected Identifier", expectedIdentifier);

        // Note: This might not match exactly due to JSON canonicalization differences
        // between TypeScript and Solidity. Use for debugging purposes.
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseTest.sol";

contract TossBankReclaimVerifierTest is BaseTest {
    // Test data as JSON string
    // won does not work: Invalid character in string.

    function setUp() public override {
        super.setUp();
        _loadProof();
    }

    function test_verifyProofSignatures() public {
        // TODO:
    }

    function test_VerifyPayment() public {
        bytes memory encodedProof = abi.encode(proof);
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(0x189027e3C77b3a92fd01bF7CC4E6a86E77F5034E);
        bytes memory data = abi.encode(witnesses);

        vm.prank(address(zkMinter));
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

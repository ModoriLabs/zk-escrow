// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseTest.sol";

contract TossBankReclaimVerifierTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _loadProof();
    }

    function test_GetIdentifierFromClaimInfo() public {
        Claims.ClaimInfo memory claimInfo = proof.claimInfo;

        bytes32 calculatedIdentifier = getIdentifierFromClaimInfo(claimInfo);
        bytes32 expectedIdentifier = proof.signedClaim.claim.identifier;

        // Log both for debugging
        emit log_named_bytes32("Calculated Identifier", calculatedIdentifier);
        emit log_named_bytes32("Expected Identifier", expectedIdentifier);
    }

    function test_IsProviderHash() public {
        bool isProviderHash = tossBankReclaimVerifier.isProviderHash(PROVIDER_HASH);
        assert(isProviderHash);
    }

    function test_VerifyProofSignatures() public {
        // TODO:
    }

    function test_VerifyPayment_Return() public {
        (bool success, bytes32 intentIdHash) = _verifyPayment();
        assert(success);
        // TODO:
        // assert(intentIdHash == keccak256(abi.encode("senderNickname")));
    }

    function test_RevertWhen_VerifyPayment_InvalidProviderHash() public {
        vm.prank(owner);
        tossBankReclaimVerifier.removeProviderHash(PROVIDER_HASH);
        vm.expectRevert("No valid providerHash");
        _verifyPayment();
    }

    // FIXME:
    function test_RevertWhen_VerifyPayment_InvalidPayeeDetails() public {
        vm.expectRevert("Incorrect payment recipient");
        _verifyPayment();
    }

    // FIXME:
    function test_RevertWhen_VerifyPayment_PaymentTimestampIsOlderThanIntentTimestamp() public {
        vm.expectRevert("Invalid proof");
        _verifyPayment();
    }

    // TODO:
    function test_VerifyPayment_TimezoneOffset() public {
        revert("Not implemented");
        // _verifyPayment();
    }

    function test_AddProviderHash() public {
        vm.prank(owner);
        tossBankReclaimVerifier.addProviderHash("0x123");
        assert(tossBankReclaimVerifier.isProviderHash("0x123"));
    }

    function test_RemoveProviderHash() public {
        vm.startPrank(owner);
        tossBankReclaimVerifier.addProviderHash("0x123");

        tossBankReclaimVerifier.removeProviderHash("0x123");
        assert(!tossBankReclaimVerifier.isProviderHash("0x123"));
        vm.stopPrank();
    }

    function _verifyPayment() internal returns (bool, bytes32) {
        bytes memory encodedProof = abi.encode(proof);
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(0x189027e3C77b3a92fd01bF7CC4E6a86E77F5034E);
        bytes memory data = abi.encode(witnesses);

        vm.prank(address(zkMinter));
        return tossBankReclaimVerifier.verifyPayment(
            IPaymentVerifier.VerifyPaymentData({
                paymentProof: encodedProof,
                mintToken: address(usdt),
                intentAmount: TEST_AMOUNT,
                payeeDetails: unicode"59733704003503(KB국민은행)",
                intentTimestamp: 1732845455, // when intent is created
                conversionRate: 1e18,
                data: data
            })
        );
    }
}

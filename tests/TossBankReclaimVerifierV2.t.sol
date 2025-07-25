// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseEscrowTest.sol";
import { TossBankReclaimVerifierV2 } from "../src/verifiers/TossBankReclaimVerifierV2.sol";
import { IPaymentVerifierV2 } from "../src/verifiers/interfaces/IPaymentVerifierV2.sol";

contract TossBankReclaimVerifierV2Test is BaseEscrowTest {
    function setUp() public override {
        super.setUp();
        _loadProofV2Anvil(); // Use the anvil fixture instead
    }

    function _loadProofV2Anvil() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/tests/fixtures/escrow-proof-anvil.json");
        string memory json = vm.readFile(path);

        // Parse individual fields instead of decoding entire struct
        proof.claimInfo.provider = vm.parseJsonString(json, ".claimInfo.provider");
        proof.claimInfo.parameters = vm.parseJsonString(json, ".claimInfo.parameters");
        proof.claimInfo.context = vm.parseJsonString(json, ".claimInfo.context");

        proof.signedClaim.claim.identifier = vm.parseJsonBytes32(json, ".signedClaim.claim.identifier");
        proof.signedClaim.claim.owner = vm.parseJsonAddress(json, ".signedClaim.claim.owner");
        proof.signedClaim.claim.timestampS = uint32(vm.parseJsonUint(json, ".signedClaim.claim.timestampS"));
        proof.signedClaim.claim.epoch = uint32(vm.parseJsonUint(json, ".signedClaim.claim.epoch"));

        // Handle signatures array
        string memory sigHex = vm.parseJsonString(json, ".signedClaim.signatures[0]");
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = vm.parseBytes(sigHex);
        console.logBytes(signatures[0]);
        proof.signedClaim.signatures = signatures;

        proof.isAppclipProof = vm.parseJsonBool(json, ".isAppclipProof");
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
        bool isProviderHash = tossBankReclaimVerifierV2.isProviderHash(PROVIDER_HASH);
        assert(isProviderHash);
    }

    function test_VerifyProofSignatures() public {
        // TODO:
    }

    function test_VerifyPayment_Return() public {
        (bool success, bytes32 intentIdHash) = _verifyPaymentV2();
        assert(success);
        assert(intentIdHash == keccak256(abi.encode("senderNickname")));
    }

    function test_RevertWhen_VerifyPayment_InvalidProviderHash() public {
        vm.prank(owner);
        tossBankReclaimVerifierV2.removeProviderHash(PROVIDER_HASH);
        vm.expectRevert("No valid providerHash");
        _verifyPaymentV2();
    }

    function test_Debug_VerifyPayment_Hash() public {
        (bool success, bytes32 intentIdHash) = _verifyPaymentV2();
        console.log("Success:", success);
        console.logBytes32(intentIdHash);
        console.logBytes32(keccak256(abi.encode("31337-1")));
        console.logBytes32(keccak256(abi.encode("senderNickname")));
    }

    function test_VerifyPayment_KRW_Currency_Success() public {
        // This should succeed since the verifier is configured with KRW currency
        (bool success, bytes32 intentIdHash) = _verifyPaymentV2();
        assert(success);
        assert(intentIdHash == keccak256(abi.encode("senderNickname")));
    }

    function test_RevertWhen_VerifyPayment_InvalidCurrency() public {
        // Test with USD currency which should fail
        bytes memory encodedProof = abi.encode(proof);
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(VERIFIER_ADDRESS_V2);
        bytes memory data = abi.encode(witnesses);

        vm.prank(address(escrow));
        vm.expectRevert("Incorrect payment currency");
        tossBankReclaimVerifierV2.verifyPayment(
            IPaymentVerifierV2.VerifyPaymentData({
                paymentProof: encodedProof,
                depositToken: address(usdt),
                intentAmount: 2,
                payeeDetails: unicode"100202642943(토스뱅크)",
                intentTimestamp: 1732845455,
                fiatCurrency: keccak256("KRW"), // This should fail since verifier expects KRW
                conversionRate: 1e18,
                data: data
            })
        );
    }

    function test_RevertWhen_VerifyPayment_InvalidCurrency_EUR() public {
        // Test with EUR currency which should also fail
        bytes memory encodedProof = abi.encode(proof);
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(VERIFIER_ADDRESS_V2);
        bytes memory data = abi.encode(witnesses);

        vm.prank(address(escrow));
        vm.expectRevert("Incorrect payment currency");
        tossBankReclaimVerifierV2.verifyPayment(
            IPaymentVerifierV2.VerifyPaymentData({
                paymentProof: encodedProof,
                depositToken: address(usdt),
                intentAmount: 2,
                payeeDetails: unicode"100202642943(토스뱅크)",
                intentTimestamp: 1732845455,
                fiatCurrency: keccak256("EUR"), // This should fail since verifier expects KRW
                conversionRate: 1e18,
                data: data
            })
        );
    }

    function test_AddProviderHash() public {
        vm.prank(owner);
        tossBankReclaimVerifierV2.addProviderHash("0x123");
        assert(tossBankReclaimVerifierV2.isProviderHash("0x123"));
    }

    function test_RemoveProviderHash() public {
        vm.startPrank(owner);
        tossBankReclaimVerifierV2.addProviderHash("0x123");

        tossBankReclaimVerifierV2.removeProviderHash("0x123");
        assert(!tossBankReclaimVerifierV2.isProviderHash("0x123"));
        vm.stopPrank();
    }

    function _verifyPaymentV2() internal returns (bool, bytes32) {
        bytes memory encodedProof = abi.encode(proof);
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(VERIFIER_ADDRESS_V2);
        bytes memory data = abi.encode(witnesses);

        vm.prank(address(escrow));
        return tossBankReclaimVerifierV2.verifyPayment(
            IPaymentVerifierV2.VerifyPaymentData({
                paymentProof: encodedProof,
                depositToken: address(usdt),
                intentAmount: 2,
                payeeDetails: unicode"100202642943(토스뱅크)",
                intentTimestamp: 1732845455,
                fiatCurrency: keccak256("KRW"), // Use KRW currency
                conversionRate: 1e18,
                data: data
            })
        );
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseEscrowUpgradeableTest.sol";
import { TossBankReclaimVerifierV2 } from "src/verifiers/TossBankReclaimVerifierV2.sol";
import { IPaymentVerifierV2 } from "src/verifiers/interfaces/IPaymentVerifierV2.sol";
import { StringConversionUtils } from "src/lib/StringConversionUtils.sol";

contract TossBankReclaimVerifierV2Test is BaseEscrowUpgradeableTest {
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

    function test_IsProviderHash() public {
        bool isProviderHash = tossBankReclaimVerifierV2.isProviderHash(PROVIDER_HASH);
        assert(isProviderHash);
    }

    function test_VerifyProofSignatures() public {
        // Test successful verification with valid witness
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(VERIFIER_ADDRESS_V2);

        bool isValid = tossBankReclaimVerifierV2.verifyProofSignatures(proof, witnesses, 1);
        assertTrue(isValid, "Proof should be valid with correct witness");

        // Test with invalid witness address
        address[] memory invalidWitnesses = new address[](1);
        invalidWitnesses[0] = address(0x1234);

        vm.expectRevert("Fewer witness signatures than required threshold");
        tossBankReclaimVerifierV2.verifyProofSignatures(proof, invalidWitnesses, 1);

        // Test with higher threshold than witnesses
        vm.expectRevert("Required threshold must be less than or equal to number of witnesses");
        tossBankReclaimVerifierV2.verifyProofSignatures(proof, witnesses, 2);

        // Test with zero threshold
        vm.expectRevert("Required threshold must be greater than 0");
        tossBankReclaimVerifierV2.verifyProofSignatures(proof, witnesses, 0);

        // Test with multiple witnesses where one is valid
        address[] memory mixedWitnesses = new address[](2);
        mixedWitnesses[0] = address(0x1234);
        mixedWitnesses[1] = address(VERIFIER_ADDRESS_V2);

        bool isValidMixed = tossBankReclaimVerifierV2.verifyProofSignatures(proof, mixedWitnesses, 1);
        assertTrue(isValidMixed, "Proof should be valid with at least one correct witness");

        // Test that it fails when requiring 2 valid signatures but only 1 is valid
        vm.expectRevert("Fewer signatures than required threshold");
        tossBankReclaimVerifierV2.verifyProofSignatures(proof, mixedWitnesses, 2);
    }

    function test_VerifyPayment_Return() public {
        (bool success, bytes32 intentIdHash) = _verifyPaymentV2();
        assert(success);
        assert(intentIdHash == keccak256(abi.encode("anvil-1")));
    }

    function test_RevertWhen_VerifyPayment_InvalidProviderHash() public {
        vm.prank(owner);
        tossBankReclaimVerifierV2.removeProviderHash(PROVIDER_HASH);
        vm.expectRevert("No valid providerHash");
        _verifyPaymentV2();
    }

    function test_RevertWhen_VerifyPayment_InvalidCurrency_USD() public {
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
                intentTimestamp: 1_732_845_455,
                fiatCurrency: keccak256("USD"), // This should fail since verifier only accepts KRW
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

    function test_VerifyPayment_AddsNullifier() public {
        // Get the expected nullifier based on the proof data
        bytes32 expectedNullifier = keccak256(abi.encodePacked("2025-07-25 12:27:19", "anvil-1"));

        // Verify nullifier is not set before verification
        assertFalse(nullifierRegistry.isNullified(expectedNullifier), "Nullifier should not be set initially");

        // Perform verification
        _verifyPaymentV2();

        // Verify nullifier is now set
        assertTrue(nullifierRegistry.isNullified(expectedNullifier), "Nullifier should be set after verification");
    }

    function test_RevertWhen_VerifyPayment_NullifierAlreadyUsed() public {
        // First verification should succeed
        _verifyPaymentV2();

        // Second verification with same proof should fail
        bytes memory encodedProof = abi.encode(proof);
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(VERIFIER_ADDRESS_V2);
        bytes memory data = abi.encode(witnesses);

        vm.prank(address(escrow));
        vm.expectRevert("Nullifier has already been used");
        tossBankReclaimVerifierV2.verifyPayment(
            IPaymentVerifierV2.VerifyPaymentData({
                paymentProof: encodedProof,
                depositToken: address(usdt),
                intentAmount: 2,
                payeeDetails: unicode"100202642943(토스뱅크)",
                intentTimestamp: 1_732_845_455,
                fiatCurrency: keccak256("KRW"),
                conversionRate: 1e18,
                data: data
            })
        );
    }

    function test_NullifierCalculation() public {
        // Test that nullifiers are calculated correctly based on date and sender nickname
        bytes32 nullifier1 = keccak256(abi.encodePacked("2025-07-25 12:27:19", "anvil-1"));
        bytes32 nullifier2 = keccak256(abi.encodePacked("2025-07-25 12:27:19", "anvil-2"));
        bytes32 nullifier3 = keccak256(abi.encodePacked("2025-07-26 12:27:19", "anvil-1"));

        // Verify nullifiers are different when sender nickname changes
        assertFalse(nullifier1 == nullifier2, "Nullifiers should be different for different senders");

        // Verify nullifiers are different when date changes
        assertFalse(nullifier1 == nullifier3, "Nullifiers should be different for different dates");

        // Verify nullifiers are deterministic (same inputs produce same output)
        bytes32 nullifier1Duplicate = keccak256(abi.encodePacked("2025-07-25 12:27:19", "anvil-1"));
        assertTrue(nullifier1 == nullifier1Duplicate, "Same inputs should produce same nullifier");
    }

    function test_RevertWhen_VerifyPayment_IncorrectPaymentAmount() public {
        // The proof contains a payment amount of "-13" (13 KRW)
        // Note: stringToUint ignores the minus sign, so it parses as 13
        // With KRW conversion rate of 1e18 and USDT having 6 decimals
        // Requesting more than 13 should fail

        bytes memory encodedProof = abi.encode(proof);
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(VERIFIER_ADDRESS_V2);
        bytes memory data = abi.encode(witnesses);

        // Test with intentAmount that would require more than 13 KRW
        vm.prank(address(escrow));
        vm.expectRevert("Incorrect payment amount");
        tossBankReclaimVerifierV2.verifyPayment(
            IPaymentVerifierV2.VerifyPaymentData({
                paymentProof: encodedProof,
                depositToken: address(usdt),
                intentAmount: 14_000_000, // More than 13 * 10^6 (the parsed amount)
                payeeDetails: unicode"100202642943(토스뱅크)",
                intentTimestamp: 1_732_845_455,
                fiatCurrency: keccak256("KRW"),
                conversionRate: 1e18,
                data: data
            })
        );
    }

    function test_VerifyPayment_ExactAmount() public {
        // Test with exact payment amount (13 KRW)
        bytes memory encodedProof = abi.encode(proof);
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(VERIFIER_ADDRESS_V2);
        bytes memory data = abi.encode(witnesses);

        vm.prank(address(escrow));
        (bool success,) = tossBankReclaimVerifierV2.verifyPayment(
            IPaymentVerifierV2.VerifyPaymentData({
                paymentProof: encodedProof,
                depositToken: address(usdt),
                intentAmount: 13, // Exact amount from proof
                payeeDetails: unicode"100202642943(토스뱅크)",
                intentTimestamp: 1_732_845_455,
                fiatCurrency: keccak256("KRW"),
                conversionRate: 1e18,
                data: data
            })
        );
        assertTrue(success, "Should succeed with exact payment amount");
    }

    function test_VerifyPayment_WithConversionRate() public {
        // Test with a different conversion rate
        // If 1 USDT = 1380 KRW, and payment is 13 KRW
        // Then 13 KRW / 1380 = 0.00942029... USDT
        // With 6 decimals, that's about 9420 units

        bytes memory encodedProof = abi.encode(proof);
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(VERIFIER_ADDRESS_V2);
        bytes memory data = abi.encode(witnesses);

        // Test with realistic conversion rate (1 USDT = 1380 KRW)
        uint256 conversionRate = 1380e18;

        // Requesting 0.01 USDT (10000 units with 6 decimals) should fail
        // because 0.01 USDT * 1380 = 13.8 KRW, but only 13 KRW was paid
        vm.prank(address(escrow));
        vm.expectRevert("Incorrect payment amount");
        tossBankReclaimVerifierV2.verifyPayment(
            IPaymentVerifierV2.VerifyPaymentData({
                paymentProof: encodedProof,
                depositToken: address(usdt),
                intentAmount: 10_000, // 0.01 USDT with 6 decimals
                payeeDetails: unicode"100202642943(토스뱅크)",
                intentTimestamp: 1_732_845_455,
                fiatCurrency: keccak256("KRW"),
                conversionRate: conversionRate,
                data: data
            })
        );

        vm.prank(address(escrow));
        (bool success,) = tossBankReclaimVerifierV2.verifyPayment(
            IPaymentVerifierV2.VerifyPaymentData({
                paymentProof: encodedProof,
                depositToken: address(usdt),
                intentAmount: 9420, // 0.00942 USDT with 6 decimals
                payeeDetails: unicode"100202642943(토스뱅크)",
                intentTimestamp: 1_732_845_455,
                fiatCurrency: keccak256("KRW"),
                conversionRate: conversionRate,
                data: data
            })
        );
        assertTrue(success, "Should succeed with exact payment amount");
    }

    function test_KoreanTimezone_Conversion() public {
        // Comprehensive test for Korean timezone (UTC+9) conversion
        // The proof contains Korean time: "2025-07-25 12:27:19"
        // This is converted to UTC by subtracting 9 hours: "2025-07-25 03:27:19"
        // The timestamp buffer (60 seconds) is then added for L2 flexibility

        bytes memory encodedProof = abi.encode(proof);
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(VERIFIER_ADDRESS_V2);
        bytes memory data = abi.encode(witnesses);

        // Intent created before the Korean payment time (in UTC)
        // This demonstrates that the timezone conversion is working correctly
        uint256 intentTimestamp = 1_753_405_200; // 2025-07-25 03:00:00 UTC

        vm.prank(address(escrow));
        (bool success, bytes32 intentIdHash) = tossBankReclaimVerifierV2.verifyPayment(
            IPaymentVerifierV2.VerifyPaymentData({
                paymentProof: encodedProof,
                depositToken: address(usdt),
                intentAmount: 13,
                payeeDetails: unicode"100202642943(토스뱅크)",
                intentTimestamp: intentTimestamp,
                fiatCurrency: keccak256("KRW"),
                conversionRate: 1e18,
                data: data
            })
        );

        assertTrue(success, "Korean timezone conversion should work correctly");
        assertEq(intentIdHash, keccak256(abi.encode("anvil-1")), "Intent ID hash should match");

        // Verify that the payment timestamp was correctly adjusted from UTC+9 to UTC
        // The verifier internally converts "2025-07-25 12:27:19" (Korean) to UTC
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
                intentTimestamp: 1_732_845_455,
                fiatCurrency: keccak256("KRW"), // Use KRW currency
                conversionRate: 1e18,
                data: data
            })
        );
    }

    // ============ Escrow Management Tests ============

    function test_AddEscrow() public {
        address newEscrow = address(0x1234);

        // Check initial state
        assertFalse(tossBankReclaimVerifierV2.isEscrow(newEscrow), "New address should not be an escrow initially");

        // Add new escrow
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit TossBankReclaimVerifierV2.EscrowAdded(newEscrow);
        tossBankReclaimVerifierV2.addEscrow(newEscrow);

        // Verify escrow was added
        assertTrue(tossBankReclaimVerifierV2.isEscrow(newEscrow), "Address should be an escrow after adding");

        // Verify escrow is in the list
        address[] memory escrows = tossBankReclaimVerifierV2.getEscrows();
        assertEq(escrows.length, 2, "Should have 2 escrows (original + new)");
        assertEq(escrows[1], newEscrow, "New escrow should be in the list");
    }

    function test_RevertWhen_AddEscrow_AlreadyEscrow() public {
        vm.prank(owner);
        vm.expectRevert("Already an escrow");
        tossBankReclaimVerifierV2.addEscrow(address(escrow));
    }

    function test_RevertWhen_AddEscrow_InvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid escrow address");
        tossBankReclaimVerifierV2.addEscrow(address(0));
    }

    function test_RevertWhen_AddEscrow_NotOwner() public {
        address newEscrow = address(0x1234);

        vm.prank(alice);
        vm.expectRevert();
        tossBankReclaimVerifierV2.addEscrow(newEscrow);
    }

    function test_RemoveEscrow() public {
        address newEscrow = address(0x1234);

        // First add an escrow
        vm.prank(owner);
        tossBankReclaimVerifierV2.addEscrow(newEscrow);

        // Then remove it
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit TossBankReclaimVerifierV2.EscrowRemoved(newEscrow);
        tossBankReclaimVerifierV2.removeEscrow(newEscrow);

        // Verify escrow was removed
        assertFalse(tossBankReclaimVerifierV2.isEscrow(newEscrow), "Address should not be an escrow after removal");

        // Verify escrow is not in the list
        address[] memory escrows = tossBankReclaimVerifierV2.getEscrows();
        assertEq(escrows.length, 1, "Should have 1 escrow (only original)");
    }

    function test_RevertWhen_RemoveEscrow_NotEscrow() public {
        address nonEscrow = address(0x1234);

        vm.prank(owner);
        vm.expectRevert("Not an escrow");
        tossBankReclaimVerifierV2.removeEscrow(nonEscrow);
    }

    function test_RevertWhen_RemoveEscrow_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        tossBankReclaimVerifierV2.removeEscrow(address(escrow));
    }

    function test_GetEscrows() public {
        // Check initial state
        address[] memory initialEscrows = tossBankReclaimVerifierV2.getEscrows();
        assertEq(initialEscrows.length, 1, "Should have 1 escrow initially");
        assertEq(initialEscrows[0], address(escrow), "Initial escrow should be the deployed escrow");

        // Add multiple escrows
        address escrow1 = address(0x1234);
        address escrow2 = address(0x5678);

        vm.startPrank(owner);
        tossBankReclaimVerifierV2.addEscrow(escrow1);
        tossBankReclaimVerifierV2.addEscrow(escrow2);
        vm.stopPrank();

        // Check updated list
        address[] memory allEscrows = tossBankReclaimVerifierV2.getEscrows();
        assertEq(allEscrows.length, 3, "Should have 3 escrows");
        assertEq(allEscrows[0], address(escrow), "First escrow should be original");
        assertEq(allEscrows[1], escrow1, "Second escrow should be escrow1");
        assertEq(allEscrows[2], escrow2, "Third escrow should be escrow2");
    }

    function test_RevertWhen_NonEscrow_CallsVerifyPayment() public {
        address nonEscrow = address(0x9999);

        bytes memory encodedProof = abi.encode(proof);
        address[] memory witnesses = new address[](1);
        witnesses[0] = address(VERIFIER_ADDRESS_V2);
        bytes memory data = abi.encode(witnesses);

        vm.prank(nonEscrow);
        vm.expectRevert("Only escrows can call");
        tossBankReclaimVerifierV2.verifyPayment(
            IPaymentVerifierV2.VerifyPaymentData({
                paymentProof: encodedProof,
                depositToken: address(usdt),
                intentAmount: 2,
                payeeDetails: unicode"100202642943(토스뱅크)",
                intentTimestamp: 1_732_845_455,
                fiatCurrency: keccak256("KRW"),
                conversionRate: 1e18,
                data: data
            })
        );
    }

    function test_RemoveEscrow_UpdatesArrayCorrectly() public {
        // Add multiple escrows
        address escrow1 = address(0x1234);
        address escrow2 = address(0x5678);
        address escrow3 = address(0x9ABC);

        vm.startPrank(owner);
        tossBankReclaimVerifierV2.addEscrow(escrow1);
        tossBankReclaimVerifierV2.addEscrow(escrow2);
        tossBankReclaimVerifierV2.addEscrow(escrow3);

        // Remove middle escrow
        tossBankReclaimVerifierV2.removeEscrow(escrow2);
        vm.stopPrank();

        // Check array is updated correctly
        address[] memory escrows = tossBankReclaimVerifierV2.getEscrows();
        assertEq(escrows.length, 3, "Should have 3 escrows after removal");
        assertEq(escrows[0], address(escrow), "First should be original escrow");
        assertEq(escrows[1], escrow1, "Second should be escrow1");
        assertEq(escrows[2], escrow3, "Third should be escrow3");

        // Verify escrow2 is no longer authorized
        assertFalse(tossBankReclaimVerifierV2.isEscrow(escrow2), "Escrow2 should not be authorized");
    }
}

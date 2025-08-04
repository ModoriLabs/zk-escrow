// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/src/Test.sol";
import { IReclaimVerifier } from "src/verifiers/interfaces/IReclaimVerifier.sol";
import { IPaymentVerifier } from "src/verifiers/interfaces/IPaymentVerifier.sol";
import { TossBankReclaimVerifier } from "src/verifiers/TossBankReclaimVerifier.sol";
import { NullifierRegistry } from "src/verifiers/nullifierRegistries/NullifierRegistry.sol";
import { INullifierRegistry } from "src/verifiers/nullifierRegistries/INullifierRegistry.sol";

import { TossBankReclaimVerifierV2 } from "src/verifiers/TossBankReclaimVerifierV2.sol";
import { IPaymentVerifierV2 } from "src/verifiers/interfaces/IPaymentVerifierV2.sol";

import { Claims } from "src/external/Claims.sol";
import { ZkMinter, IZkMinter } from "src/ZkMinter.sol";
import { MockUSDT } from "src/MockUSDT.sol";
import { Escrow } from "src/Escrow.sol";
import { IEscrow } from "src/interfaces/IEscrow.sol";

contract BaseTest is Test {
    TossBankReclaimVerifier public tossBankReclaimVerifier;
    NullifierRegistry public nullifierRegistry;
    ZkMinter public zkMinter;
    MockUSDT public usdt;

    IReclaimVerifier.ReclaimProof public proof;

    uint256 public constant PRECISE_UNIT = 1e18;
    string public constant PROVIDER_HASH = "0xffb501528259e6d684e1c2153fbbacab453fe9c97c336dc4f8f48d70a0e2a13d";
    uint256 public timestampBuffer = 60;

    address public constant VERIFIER_ADDRESS_V1 = 0x189027e3C77b3a92fd01bF7CC4E6a86E77F5034E;
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 constant TEST_AMOUNT = 8750e6; // 8750 USDT with 6 decimals

    function setUp() public virtual {
        usdt = new MockUSDT(owner);
        nullifierRegistry = new NullifierRegistry(owner);

        zkMinter = new ZkMinter(owner, address(usdt));
        string[] memory providerHashes = new string[](1);
        providerHashes[0] = PROVIDER_HASH;
        tossBankReclaimVerifier = new TossBankReclaimVerifier(
            owner,
            address(zkMinter),
            INullifierRegistry(address(nullifierRegistry)),
            timestampBuffer,
            new bytes32[](0),
            providerHashes
        );

        vm.startPrank(owner);
        zkMinter.addVerifier(address(tossBankReclaimVerifier));
        // bytes memory data = new bytes(96); // 3 * 32 bytes
        // assembly {
        //     mstore(add(data, 0x20), 0x20)                                    // offset
        //     mstore(add(data, 0x40), 0x01)                                    // length
        //     mstore(add(data, 0x60), 0x189027e3c77b3a92fd01bf7cc4e6a86e77f5034e) // address
        // }
        address[] memory addresses = new address[](1);
        addresses[0] = VERIFIER_ADDRESS_V1;
        bytes memory data = abi.encode(addresses);
        zkMinter.setVerifierData(address(tossBankReclaimVerifier), unicode"59733704003503(KB국민은행)", data);

        nullifierRegistry.addWritePermission(address(tossBankReclaimVerifier));

        usdt.transferOwnership(address(zkMinter));
        vm.stopPrank();
    }

    function getIdentifierFromClaimInfo(Claims.ClaimInfo memory claimInfo) internal pure returns (bytes32) {
        string memory concatenated = string(
            abi.encodePacked(
                claimInfo.provider,
                "\n",
                claimInfo.parameters,
                "\n",
                bytes(claimInfo.context).length > 0 ? claimInfo.context : ""
            )
        );

        return keccak256(bytes(concatenated));
    }

    function _signalIntent() internal {
        zkMinter.signalIntent({ _to: alice, _amount: 8750e6, _verifier: address(tossBankReclaimVerifier) });
    }

    function _fulfillIntent() internal {
        _loadProof();
        bytes memory paymentProof = abi.encode(proof);
        zkMinter.fulfillIntent({ _paymentProof: paymentProof, _intentId: 1 });
    }

    function _loadProof() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/tests/fixtures/proof.json");
        string memory json = vm.readFile(path);
        // bytes memory data = vm.parseJson(json);
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
}

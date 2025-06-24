// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/src/Test.sol";
import { IReclaimVerifier } from "src/verifiers/interfaces/IReclaimVerifier.sol";
import { IPaymentVerifier } from "src/verifiers/interfaces/IPaymentVerifier.sol";
import { TossBankReclaimVerifier } from "src/verifiers/TossBankReclaimVerifier.sol";
import { NullifierRegistry } from "src/verifiers/nullifierRegistries/NullifierRegistry.sol";
import { INullifierRegistry } from "src/verifiers/nullifierRegistries/INullifierRegistry.sol";
import { Claims } from "src/external/Claims.sol";
import { ZkMinter } from "../src/ZkMinter.sol";
import { MockUSDT } from "../src/MockUSDT.sol";

contract BaseTest is Test {
    TossBankReclaimVerifier public tossBankReclaimVerifier;
    NullifierRegistry public nullifierRegistry;
    ZkMinter public zkMinter;
    MockUSDT public usdt;

    uint256 public timestampBuffer = 60;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");

    function setUp() public virtual {
        console.log("BaseTest setUp");

        nullifierRegistry = new NullifierRegistry(owner);

        tossBankReclaimVerifier = new TossBankReclaimVerifier(
            owner,
            address(this),
            INullifierRegistry(address(nullifierRegistry)),
            timestampBuffer,
            new bytes32[](0),
            new string[](0)
        );

        zkMinter = new ZkMinter(owner, address(usdt));
    }

    function getIdentifierFromClaimInfo(Claims.ClaimInfo memory claimInfo) internal pure returns (bytes32) {
        string memory concatenated = string(abi.encodePacked(
            claimInfo.provider,
            "\n",
            claimInfo.parameters,
            "\n",
            bytes(claimInfo.context).length > 0 ? claimInfo.context : ""
        ));

        return keccak256(bytes(concatenated));
    }
}

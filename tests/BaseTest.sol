// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/src/Test.sol";
import { IReclaimVerifier } from "src/verifiers/interfaces/IReclaimVerifier.sol";
import { IPaymentVerifier } from "src/verifiers/interfaces/IPaymentVerifier.sol";
import { TossBankReclaimVerifier } from "src/verifiers/TossBankReclaimVerifier.sol";
import { NullifierRegistry } from "src/verifiers/nullifierRegistries/NullifierRegistry.sol";
import { INullifierRegistry } from "src/verifiers/nullifierRegistries/INullifierRegistry.sol";
import { Claims } from "src/external/Claims.sol";

contract BaseTest is Test {
    TossBankReclaimVerifier public tossBankReclaimVerifier;
    NullifierRegistry public nullifierRegistry;

    uint256 public timestampBuffer = 60;

    address public owner = makeAddr("owner");

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

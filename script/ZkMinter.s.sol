// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Base.s.sol";
import { ZkMinter } from "../src/ZkMinter.sol";
import { TossBankReclaimVerifier } from "../src/verifiers/TossBankReclaimVerifier.sol";

contract ZkMinterScript is BaseScript {

    function setVerifierData() public broadcast {
        (address zkMinterAddress, address tossBankVerifierAddress) = _getDeployedAddresses();
        ZkMinter zkMinter = ZkMinter(zkMinterAddress);
        _setVerifierData(zkMinter, tossBankVerifierAddress);
    }

    function addVerifier() public broadcast {
        (address zkMinterAddress, address tossBankVerifierAddress) = _getDeployedAddresses();
        ZkMinter zkMinter = ZkMinter(zkMinterAddress);
        _addVerifier(zkMinter, tossBankVerifierAddress);
    }

    function grantMinterRole() public broadcast {
        (address zkMinterAddress,) = _getDeployedAddresses();
        _grantMinterRole(zkMinterAddress);
    }

    function _getDeployedAddresses() internal view returns (address zkMinterAddress, address tossBankVerifierAddress) {
        console.log("Chain ID:", block.chainid);
        console.log("Broadcaster:", broadcaster);

        // Use the generic function from BaseScript
        zkMinterAddress = _getDeployedAddress("ZkMinter");
        tossBankVerifierAddress = _getDeployedAddress("TossBankReclaimVerifier");
    }

    function _setVerifierData(ZkMinter zkMinter, address tossBankVerifierAddress) internal {
        // Setup verifier data
        // Setup - Set verifier data from config
        address owner = _getOwnerFromConfig(block.chainid);
        address[] memory addresses = new address[](1);
        addresses[0] = owner;
        bytes memory data = abi.encode(addresses);

        string memory bankAccount = vm.envString("BANK_ACCOUNT"); // unicode"1000-0000-0000(토스뱅크)"
        console.log("Bank Account:", bankAccount);

        zkMinter.setVerifierData(tossBankVerifierAddress, bankAccount, data);
        console.log("Successfully set verifier data for TossBankReclaimVerifier");
    }

    function _addVerifier(ZkMinter zkMinter, address tossBankVerifierAddress) internal {
        zkMinter.addVerifier(tossBankVerifierAddress);
        console.log("Successfully added TossBankReclaimVerifier to ZkMinter");
    }

    function _grantMinterRole(address zkMinterAddress) internal {
        // Get KRW address using the generic function
        address krwAddress = _getDeployedAddress("KRW");

        console.log("Granting MINTER_ROLE to ZkMinter:", zkMinterAddress);

        // Grant MINTER_ROLE to ZkMinter
        bytes32 MINTER_ROLE = keccak256("MINTER_ROLE");

        // Call grantRole on KRW contract
        (bool success,) = krwAddress.call(
            abi.encodeWithSignature("grantRole(bytes32,address)", MINTER_ROLE, zkMinterAddress)
        );

        require(success, "Failed to grant MINTER_ROLE");
        console.log("Successfully granted MINTER_ROLE to ZkMinter");
    }


}

/*
Usage Examples:

# Set verifier data
BANK_ACCOUNT="59733704003503(KB국민은행)" forge script script/ZkMinter.s.sol --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY --sig "setVerifierData()"

# Add verifier
forge script script/ZkMinter.s.sol --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY --sig "addVerifier()"

# Grant minter role to ZkMinter
forge script script/ZkMinter.s.sol --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY --sig "grantMinterRole()"

Note: Contract addresses are automatically loaded from deployments/{chainId}-deploy.json
*/

//SPDX-License-Identifier: MIT

pragma solidity 0.8.29;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IPaymentVerifier } from "./verifiers/interfaces/IPaymentVerifier.sol";
import { IZkMinter } from "./interfaces/IZkMinter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IMintableERC20 } from "./interfaces/IMintableERC20.sol";
import { StringUtils } from "./external/ReclaimStringUtils.sol";

contract ZkMinter is Ownable, Pausable, IZkMinter {
    address public token;
    uint256 public intentCount = 0;

    // Mapping of address to intentHash (Only one intent per address at a given time)
    mapping(address => uint256) public accountIntent;
    mapping(uint256 => Intent) public intents;
    address[] public verifiers;
    mapping(address => VerifierData) public verifierData;

    constructor(
        address _owner,
        address _token
    ) Ownable(_owner) {
        token = _token;
    }

    function signalIntent(
        address _to,
        uint256 _amount,
        address _verifier
    ) external whenNotPaused {
        require(_to != address(0), "Invalid recipient address");
        require(_amount > 0, InvalidAmount());
        require(_verifier != address(0), "Invalid verifier address");

        // Check if an intent already exists for this address
        uint256 intentId = accountIntent[_to];
        require(intentId == 0, "Intent already exists for this address");

        // Create a new intent
        intentId = ++intentCount;
        intents[intentId] = Intent({
            owner: msg.sender,
            to: _to,
            amount: _amount,
            timestamp: block.timestamp,
            paymentVerifier: _verifier
        });

        accountIntent[_to] = intentId;

        emit IntentSignaled(_to, _verifier, _amount, intentId);
    }

    // allowed even when paused
//    function cancelIntent() external {
//        // TODO:
//    }

    function fulfillIntent(
        bytes calldata _paymentProof,
        uint256 _intentId
    ) external whenNotPaused {
        Intent memory intent = intents[_intentId];

        address verifier = intent.paymentVerifier;
        require(verifier != address(0), IntentNotFound());

        (bool success, bytes32 intentHash) = IPaymentVerifier(verifier).verifyPayment(
            IPaymentVerifier.VerifyPaymentData({
                paymentProof: _paymentProof,
                intentAmount: intent.amount,
                intentTimestamp: intent.timestamp,
                conversionRate: 1e18, // PRECISE_UNIT is 1e18
                data: verifierData[verifier].data
            })
        );
        require(success, "Payment verification failed");
        require(keccak256(abi.encode(intent.amount)) == intentHash, "Intent hash mismatch");

        IMintableERC20(token).mint(intent.to, intent.amount);
    }

    // *** Governance functions ***

    function addVerifier(
        address _verifier
    ) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        verifiers.push(_verifier);
    }

    function removeVerifier(
        address _verifier
    ) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        require(verifiers.length > 0, "No verifiers to remove");

        for (uint256 i = 0; i < verifiers.length; i++) {
            if (verifiers[i] == _verifier) {
                verifiers[i] = verifiers[verifiers.length - 1];
                verifiers.pop();
                break;
            }
        }
    }

    function setVerifierData(
        address _verifier,
        string calldata _payeeDetails,
        bytes calldata _data
    ) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        verifierData[_verifier] = VerifierData({
            payeeDetails: _payeeDetails,
            data: _data
        });
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}

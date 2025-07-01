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
    uint256 public intentCount;
    uint256 public redeemCount;

    // Mapping of address to intentHash (Only one intent per address at a given time)
    mapping(address => uint256) public accountIntent;
    mapping(uint256 => Intent) public intents;
    address[] public verifiers;
    mapping(address => DepositVerifierData) public depositVerifierData;

    mapping(address => uint256) public accountRedeemRequest;
    mapping(uint256 => RedeemRequest) public redeemRequests;

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
        uint256 intentId = accountIntent[msg.sender];
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

        accountIntent[msg.sender] = intentId;

        emit IntentSignaled(_to, _verifier, _amount, intentId);
    }

    /**
     * @notice Only callable by the originator of the intent. Allowed even when paused.
     *
     * @param _intentId    ID of intent being cancelled
     */
    function cancelIntent(uint256 _intentId) external {
        Intent memory intent = intents[_intentId];
        require(intent.owner == msg.sender, "Sender must be the intent owner");
        _pruneIntent(_intentId);
        emit IntentCancelled(_intentId);
    }

    function fulfillIntent(
        bytes calldata _paymentProof,
        uint256 _intentId
    ) external whenNotPaused {
        Intent memory intent = intents[_intentId];

        address verifier = intent.paymentVerifier;
        require(verifier != address(0), IntentNotFound());

        DepositVerifierData memory verifierData = depositVerifierData[verifier];
        (bool success, bytes32 intentHash) = IPaymentVerifier(verifier).verifyPayment(
            IPaymentVerifier.VerifyPaymentData({
                paymentProof: _paymentProof,
                mintToken: token,
                intentAmount: intent.amount,
                intentTimestamp: intent.timestamp,
                payeeDetails: verifierData.payeeDetails,
                conversionRate: 1e18, // PRECISE_UNIT is 1e18
                data: verifierData.data
            })
        );
        require(success, "Payment verification failed");
        require(keccak256(abi.encode(StringUtils.uint2str(_intentId))) == intentHash, "Intent hash mismatch");

        _pruneIntent(_intentId);

        IMintableERC20(token).mint(intent.to, intent.amount);

        emit IntentFulfilled(
            intentHash,
            verifier,
            intent.owner,
            intent.to,
            intent.amount
        );
    }

    function signalRedeem(
        string calldata _accountNumber,
        uint256 _amount
    ) external whenNotPaused {
        require(_amount > 0, InvalidAmount());
        require(bytes(_accountNumber).length > 0, InvalidAccountNumber());
        require(accountRedeemRequest[msg.sender] == 0, RedeemAlreadyExists());

        // Transfer tokens from user to this contract for escrow
        IERC20(token).transferFrom(msg.sender, address(this), _amount);

        uint256 redeemId = ++redeemCount;
        redeemRequests[redeemId] = RedeemRequest({
            owner: msg.sender,
            amount: _amount,
            timestamp: block.timestamp
        });

        accountRedeemRequest[msg.sender] = redeemId;
        emit RedeemRequestSignaled(redeemId, msg.sender, _amount, _accountNumber);
    }

    /**
     * @notice Only callable by the originator of the intent. Allowed even when paused.
     * @dev Returns escrowed tokens back to user
     *
     * @param _redeemId    ID of redeem request being cancelled
     */
    function cancelRedeem(uint256 _redeemId) external {
        RedeemRequest memory redeemRequest = redeemRequests[_redeemId];
        require(redeemRequest.owner == msg.sender, "Sender must be the redeem request owner");

        _pruneRedeemRequest(_redeemId);

        // memory redeeRequest is not deleted
        IERC20(token).transfer(redeemRequest.owner, redeemRequest.amount);
        emit RedeemRequestCancelled(_redeemId);
    }

    /**
     * @notice Only callable by the owner. Allowed even when paused.
     * @dev Burns escrowed tokens from this contract
     *
     * @param _redeemId    ID of redeem request being fulfilled
     */
    function fulfillRedeem(uint256 _redeemId) external onlyOwner {
        RedeemRequest memory redeemRequest = redeemRequests[_redeemId];
        require(redeemRequest.amount > 0, RedeemRequestNotFound());

        IMintableERC20(token).burn(redeemRequest.amount);

        _pruneRedeemRequest(_redeemId);
        emit RedeemRequestFulfilled(_redeemId);
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
        depositVerifierData[_verifier] = DepositVerifierData({
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

    function _pruneIntent(uint256 _intentId) internal {
        delete accountIntent[intents[_intentId].owner];
        delete intents[_intentId];
    }

    function _pruneRedeemRequest(uint256 _redeemId) internal {
        delete accountRedeemRequest[redeemRequests[_redeemId].owner];
        delete redeemRequests[_redeemId];
    }
}

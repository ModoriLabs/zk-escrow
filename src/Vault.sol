// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract Vault {
    address public immutable usdt;
    address public notary;

    uint256 public constant MAX_ALLOWED_AMOUNT = 10 * 1e6; // 10 USDT (6 decimals)

    struct Enrollment {
        uint64 binanceId;
        uint256 amount;
        bool claimed;
    }

    mapping(uint256 => Enrollment) public enrollments;

    event Enrolled(uint256 indexed orderId, uint64 binanceId, uint256 amount);
    event Claimed(uint256 indexed orderId, address indexed to, uint256 amount);
    event Debug(string message, address value);
    event DebugBytes32(string message, bytes32 value);

    constructor(address _usdt, address _notary) {
        usdt = _usdt;
        notary = _notary;
    }

    modifier withinLimit(uint256 amount) {
        require(amount <= MAX_ALLOWED_AMOUNT, "Amount exceeds 10 USDT limit");
        _;
    }

    function enroll(uint256 orderId, uint64 binanceId, uint256 amount) external withinLimit(amount) {
        require(enrollments[orderId].amount == 0, "Already enrolled");
        enrollments[orderId] = Enrollment({binanceId: binanceId, amount: amount, claimed: false});
        emit Enrolled(orderId, binanceId, amount);
    }

    // bytes32 messageHash = keccak256(abi.encodePacked(orderId, recipient, amount));
    // (uint8 v, bytes32 r, bytes32 s) = vm.sign(NOTARY_PRIVATE_KEY, messageHash);
    function claim(uint256 orderId, address recipient, uint256 amount, uint8 v, bytes32 r, bytes32 s) external {
        Enrollment storage e = enrollments[orderId];
        require(e.amount > 0, "Not enrolled");
        require(!e.claimed, "Already claimed");
        require(e.amount == amount, "Amount mismatch");

        bytes32 digest = keccak256(abi.encodePacked(orderId, recipient, amount));
        require(_isValidSignature(digest, v, r, s), "Invalid signature");

        e.claimed = true;
        require(IERC20(usdt).transfer(recipient, e.amount), "Transfer failed");

        emit Claimed(orderId, recipient, e.amount);
    }

    function _isValidSignature(bytes32 digest, uint8 v, bytes32 r, bytes32 s) internal returns (bool) {
        address signer = ecrecover(digest, v, r, s);
        emit Debug("Recovered signer", signer);
        emit Debug("Expected notary", notary);

        return signer == notary;
    }

    function updateNotary(address newNotary) external {
        require(msg.sender == notary, "Only notary can update");
        notary = newNotary;
        emit Debug("Updated notary", newNotary);
    }

    function changeNotary(address newNotary) external {
        require(msg.sender == notary, "Only notary can change");
        notary = newNotary;
        emit Debug("Changed notary", newNotary);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract Vault {
    address public immutable usdt;
    address public notary;

    uint256 public constant MAX_ALLOWED_AMOUNT = 10 * 1e6; // 10 USDT (6 decimals)

    struct Enrollment {
        string from_binance_id;
        address recipient;
        uint256 amount;
        bool claimed;
    }

    mapping(bytes32 => Enrollment) public enrollments;
    mapping(address => bytes32) public recipientToEnrollId;

    bytes32[] public enrolledIds;

    event Enrolled(string from_binance_id, address recipient, uint256 amount);
    event Claimed(bytes32 enrollId, uint256 amount);
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

    function _createEnrollId(string memory from_binance_id, address recipient) internal view returns (bytes32) {
        uint256 timestamp = block.timestamp;
        bytes32 messageHash = keccak256(abi.encodePacked(from_binance_id, recipient, timestamp));
        return messageHash;
    }

    function enroll(string memory from_binance_id, address recipient, uint256 amount) external withinLimit(amount) {
        bytes32 enrollId = _createEnrollId(from_binance_id, recipient);
        require(enrollments[enrollId].amount == 0, "Already enrolled");
        enrollments[enrollId] =
            Enrollment({from_binance_id: from_binance_id, recipient: recipient, amount: amount, claimed: false});
        enrolledIds.push(enrollId);
        recipientToEnrollId[recipient] = enrollId;
        emit Enrolled(from_binance_id, recipient, amount);
    }

    // bytes32 messageHash = keccak256(abi.encodePacked(enrollId, amount));
    // (uint8 v, bytes32 r, bytes32 s) = vm.sign(NOTARY_PRIVATE_KEY, messageHash);
    function claim(bytes32 enrollId, uint256 amount, uint8 v, bytes32 r, bytes32 s) external {
        Enrollment storage e = enrollments[enrollId];
        require(e.amount > 0, "Not enrolled");
        require(!e.claimed, "Already claimed");
        require(e.amount == amount, "Amount mismatch");

        bytes32 digest = keccak256(abi.encodePacked(enrollId, amount));
        require(_isValidSignature(digest, v, r, s), "Invalid signature");

        e.claimed = true;
        delete recipientToEnrollId[e.recipient];

        require(IERC20(usdt).transfer(e.recipient, e.amount), "Transfer failed");

        emit Claimed(enrollId, amount);
    }

    function _isValidSignature(bytes32 digest, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        address signer = ecrecover(digest, v, r, s);

        return signer == notary;
    }

    function updateNotary(address newNotary) external {
        require(msg.sender == notary, "Only notary can update");
        notary = newNotary;
    }

    // for dev
    function clearEnrollments() external {
        require(msg.sender == notary, "Only notary can clear");
        for (uint256 i = 0; i < enrolledIds.length; i++) {
            address recipient = enrollments[enrolledIds[i]].recipient;
            delete recipientToEnrollId[recipient];
            delete enrollments[enrolledIds[i]];
        }
        delete enrolledIds;
    }
}

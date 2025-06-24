// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface INullifierRegistry {
    function isNullified(bytes32 _nullifier) external view returns (bool);
    function addNullifier(bytes32 _nullifier) external;
}

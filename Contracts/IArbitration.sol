// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IArbitration {
    function arbitrate(uint256 jobId, bool clientWins) external;
}

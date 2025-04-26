// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IEscrow {
    function postJob() external payable returns (uint256);
    function acceptJob(uint256 jobId) external;
    function submitWork(uint256 jobId) external;
    function confirmCompletion(uint256 jobId) external;
    function raiseDispute(uint256 jobId) external;
}

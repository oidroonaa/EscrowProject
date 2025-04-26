// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library SafePayment {
    function pullPayment(address payable recipient, uint256 amount) internal {
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Payment failed");
    }
}

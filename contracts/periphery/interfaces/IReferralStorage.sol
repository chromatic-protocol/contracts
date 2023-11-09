// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IReferralStorage {
    event ReferrerSet(address indexed trader, address indexed referrer);

    function referredBy(address trader) external returns (address referrer);

    function setReferrer(address trader, address referrer) external;
}

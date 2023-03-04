// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStrategy {
    // Total want tokens managed by stratfegy
    function wantLockedTotal() external view returns (uint256);

    // Sum of all shares of users to wantLockedTotal
    function sharesTotal() external view returns (uint256);

    // Main want token compounding function
    function earn() external;

    // Transfer want tokens portFarm -> strategy
    function deposit(
        address _userAddress,
        uint256 _wantAmt
    ) external returns (uint256);

    // Transfer want tokens strategy -> portFarm
    function withdraw(
        address _userAddress,
        uint256 _wantAmt
    ) external returns (uint256);

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) external;
}

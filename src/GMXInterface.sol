// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

// Minimal interface wrappers compatible with 0.8.0
// These match the GMX interfaces from the submodule but use 0.8.0 syntax
// When forking, you're calling deployed contracts, so version doesn't matter at runtime

interface IVault {
    function getMaxPrice(address _token) external view returns (uint256);
    function getMinPrice(address _token) external view returns (uint256);
    function usdg() external view returns (address);
    function gov() external view returns (address);
    function whitelistedTokens(address _token) external view returns (bool);
    function poolAmounts(address _token) external view returns (uint256);
    function tokenBalances(address _token) external view returns (uint256);
    function reservedAmounts(address _token) external view returns (uint256);
    function increasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong
    ) external;
    function decreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver
    ) external returns (uint256);
    // Add more functions as needed from lib/gmx-contracts/contracts/core/interfaces/IVault.sol
}

interface IRouter {
    function swap(
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minOut,
        address _receiver
    ) external returns (uint256);
    // Add more functions as needed from lib/gmx-contracts/contracts/core/interfaces/IRouter.sol
}

// Contract addresses on Arbitrum:
// GMX Vault: 0x489ee077994B6658eAfA855C308275EAd8097C4A
// GMX Router: 0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064
//
// Note: You can reference the actual GMX interfaces in lib/gmx-contracts/contracts/core/interfaces/
// to see all available functions. This wrapper only includes commonly used ones.

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

// Extended interfaces for GMX contracts (0.8.0 compatible wrappers)
// Reference actual interfaces in lib/gmx-contracts/contracts/core/interfaces/

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IOrderBook {
    function createIncreaseOrder(
        address[] memory _path,
        uint256 _amountIn,
        address _indexToken,
        uint256 _minOut,
        uint256 _sizeDelta,
        address _collateralToken,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold,
        uint256 _executionFee,
        bool _shouldWrap
    ) external payable;
    
    function createDecreaseOrder(
        address _indexToken,
        uint256 _sizeDelta,
        address _collateralToken,
        uint256 _collateralDelta,
        bool _isLong,
        uint256 _triggerPrice,
        bool _triggerAboveThreshold
    ) external payable;
    
    function minExecutionFee() external view returns (uint256);
}

interface IPositionManager {
    function executeIncreaseOrder(
        address _account,
        uint256 _orderIndex,
        address payable _feeReceiver
    ) external;
    
    function executeDecreaseOrder(
        address _account,
        uint256 _orderIndex,
        address payable _feeReceiver
    ) external;
    
    function isOrderKeeper(address _account) external view returns (bool);
}

interface IGlpManager {
    function getAum(bool _maximise) external view returns (uint256);
    function getAumInUsdg(bool maximise) external view returns (uint256);
    function getPrice(bool maximise) external view returns (uint256);
}

interface IFastPriceFeed {
    function prices(address _token) external view returns (uint256);
}

interface IPriceFeed {
    function latestAnswer() external view returns (int256);
}

interface IRewardRouterV2 {
    function mintAndStakeGlp(
        address _token,
        uint256 _amount,
        uint256 _minUsdg,
        uint256 _minGlp
    ) external returns (uint256);
    
    function unstakeAndRedeemGlp(
        address _tokenOut,
        uint256 _glpAmount,
        uint256 _minOut,
        address _receiver
    ) external returns (uint256);
    
    function glp() external view returns (address);
    function feeGlpTracker() external view returns (address);
    function stakedGlpTracker() external view returns (address);
}

// Extended Router interface (add approvePlugin)
interface IRouterExtended {
    function approvePlugin(address _plugin) external;
}

// GLP token interface (extends ERC20)
interface IGLP {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function id() external pure returns (string memory);
}

interface ITimelock {
    function isHandler(address _handler) external view returns (bool);
    function admin() external view returns (address);
    function setContractHandler(address _handler, bool _isActive) external;
}


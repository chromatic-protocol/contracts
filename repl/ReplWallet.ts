import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { BigNumber, ethers } from "ethers"
import { parseEther, parseUnits } from "ethers/lib/utils"
import {
  IAccount,
  IAccountFactory,
  IAccountFactory__factory,
  IAccount__factory,
  IERC20Metadata,
  IERC20Metadata__factory,
  IOracleProvider,
  IOracleProvider__factory,
  ISwapRouter,
  ISwapRouter__factory,
  IUSUMMarket,
  IUSUMMarketFactory,
  IUSUMMarketFactory__factory,
  IUSUMMarket__factory,
  IUSUMRouter,
  IUSUMRouter__factory,
  IWETH9,
  IWETH9__factory,
} from "../typechain-types"
import { PositionStructOutput } from "./../typechain-types/contracts/core/interfaces/IUSUMMarket"

const QTY_DECIMALS = 4
const LEVERAGE_DECIMALS = 2
const FEE_RATE_DECIMALS = 4

export class ReplWallet {
  public readonly address: string
  public Account: IAccount

  static async create(
    signer: SignerWithAddress,
    addresses: {
      weth: string
      usdc: string
      swapRouter: string
      marketFactory: string
      oracleProvider: string
      accountFactory: string
      router: string
    },
    ensureAccount: boolean
  ): Promise<ReplWallet> {
    const weth = IWETH9__factory.connect(addresses.weth, signer)
    const usdc = IERC20Metadata__factory.connect(addresses.usdc, signer)
    const swapRouter = ISwapRouter__factory.connect(
      addresses.swapRouter,
      signer
    )
    const oracleProvider = IOracleProvider__factory.connect(
      addresses.oracleProvider,
      signer
    )
    const marketFactory = IUSUMMarketFactory__factory.connect(
      addresses.marketFactory,
      signer
    )
    const accountFactory = IAccountFactory__factory.connect(
      addresses.accountFactory,
      signer
    )
    const router = IUSUMRouter__factory.connect(addresses.router, signer)

    const marketAddress = await marketFactory.getMarket(
      oracleProvider.address,
      usdc.address
    )
    const market = IUSUMMarket__factory.connect(marketAddress, signer)

    const w = new ReplWallet(
      signer,
      weth,
      usdc,
      swapRouter,
      oracleProvider,
      marketFactory,
      market,
      router,
      accountFactory
    )

    if (ensureAccount) {
      await w.createAccount()
    }

    return w
  }

  private constructor(
    public readonly signer: SignerWithAddress,
    public readonly WETH9: IWETH9,
    public readonly USDC: IERC20Metadata,
    public readonly SwapRouter: ISwapRouter,
    public readonly OracleProvider: IOracleProvider,
    public readonly USUMMarketFactory: IUSUMMarketFactory,
    public readonly USUMMarket: IUSUMMarket,
    public readonly USUMRouter: IUSUMRouter,
    public readonly AccountFactory: IAccountFactory
  ) {
    this.address = signer.address
  }

  async createAccount() {
    let accountAddress = await this.AccountFactory["getAccount()"]()
    if (accountAddress === ethers.constants.AddressZero) {
      await this.AccountFactory.createAccount()
      accountAddress = await this.AccountFactory["getAccount()"]()
    }
    this.Account = IAccount__factory.connect(accountAddress, this.signer)
  }

  async wrapEth(eth: number) {
    await this.WETH9.deposit({ value: parseEther(eth.toString()) })
  }

  async swapEth(eth: number) {
    await this.WETH9.approve(
      this.SwapRouter.address,
      ethers.constants.MaxUint256
    )

    await this.SwapRouter.exactInputSingle({
      tokenIn: this.WETH9.address,
      tokenOut: this.USDC.address,
      // fee: 10000,
      fee: 3000,
      // fee: 500,
      recipient: this.address,
      deadline: deadline(),
      amountIn: parseEther(eth.toString()),
      amountOutMinimum: 0,
      sqrtPriceLimitX96: 0,
    })

    await this.WETH9.approve(this.SwapRouter.address, 0)
  }

  async positions(): Promise<PositionStructOutput[]> {
    const positionIds = await this.Account.getPositionIds(
      this.USUMMarket.address
    )
    return Promise.all(
      positionIds.map(
        async (positionId) => await this.USUMMarket.getPosition(positionId)
      )
    )
  }

  async openPosition(
    qty: number,
    leverage: number,
    takerMargin: number,
    makerMargin: number
  ) {
    const decimals = await this.USDC.decimals()
    const _takerMargin = parseUnits(takerMargin.toString(), decimals)
    const _makerMargin = parseUnits(makerMargin.toString(), decimals)

    await this.USUMRouter.openPosition(
      this.OracleProvider.address,
      this.USDC.address,
      parseUnits(qty.toString(), QTY_DECIMALS),
      parseUnits(leverage.toString(), LEVERAGE_DECIMALS),
      _takerMargin,
      _makerMargin,
      _makerMargin, // no limit trading fee
      deadline()
    )
  }

  async closePosition(positionId: number) {
    await this.USUMRouter.closePosition(
      this.OracleProvider.address,
      this.USDC.address,
      BigNumber.from(positionId),
      deadline()
    )
  }

  async addLiquidity(feeRate: number, amount: number) {
    const decimals = await this.USDC.decimals()
    await this.USUMRouter.addLiquidity(
      this.OracleProvider.address,
      this.USDC.address,
      parseUnits(feeRate.toString(), FEE_RATE_DECIMALS),
      parseUnits(amount.toString(), decimals),
      this.address,
      deadline()
    )
  }

  async removeLiquidity(feeRate: number, liquidity: number, amountMin: number) {
    const decimals = await this.USDC.decimals()
    await this.USUMRouter.removeLiquidity(
      this.OracleProvider.address,
      this.USDC.address,
      parseUnits(feeRate.toString(), FEE_RATE_DECIMALS),
      parseUnits(liquidity.toString(), decimals),
      parseUnits(amountMin.toString(), decimals),
      this.address,
      deadline()
    )
  }
}

function deadline(): number {
  return Math.ceil(Date.now() / 1000) + 30
}

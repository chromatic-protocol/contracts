import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { BigNumber, ethers } from 'ethers'
import { parseEther, parseUnits } from 'ethers/lib/utils'
import {
  ChromaticLens,
  ChromaticLens__factory,
  IChromaticAccount,
  IChromaticAccount__factory,
  IChromaticMarket,
  IChromaticMarketFactory,
  IChromaticMarketFactory__factory,
  IChromaticMarket__factory,
  IChromaticRouter,
  IChromaticRouter__factory,
  IERC20Metadata,
  IERC20Metadata__factory,
  IOracleProvider,
  IOracleProvider__factory,
  ISwapRouter,
  ISwapRouter__factory,
  IWETH9,
  IWETH9__factory
} from '../../typechain-types'
import { PositionStructOutput } from '../../typechain-types/contracts/core/interfaces/IChromaticMarket'

const QTY_DECIMALS = 4
const LEVERAGE_DECIMALS = 2
const FEE_RATE_DECIMALS = 4

export class ReplWallet {
  public readonly address: string
  public Account: IChromaticAccount

  static async create(
    signer: SignerWithAddress,
    addresses: {
      weth: string
      usdc: string
      swapRouter: string
      marketFactory: string
      oracleProvider: string
      router: string,
      lens: string
    },
    ensureAccount: boolean
  ): Promise<ReplWallet> {
    const weth = IWETH9__factory.connect(addresses.weth, signer)
    const usdc = IERC20Metadata__factory.connect(addresses.usdc, signer)
    const swapRouter = ISwapRouter__factory.connect(addresses.swapRouter, signer)
    const oracleProvider = IOracleProvider__factory.connect(addresses.oracleProvider, signer)
    const marketFactory = IChromaticMarketFactory__factory.connect(addresses.marketFactory, signer)
    const router = IChromaticRouter__factory.connect(addresses.router, signer)
    const lens = ChromaticLens__factory.connect(addresses.lens, signer)

    const marketAddress = await marketFactory.getMarkets()

    const market = IChromaticMarket__factory.connect(marketAddress[0], signer)

    const w = new ReplWallet(
      signer,
      weth,
      usdc,
      swapRouter,
      oracleProvider,
      marketFactory,
      market,
      router,
      lens
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
    public readonly ChromaticMarketFactory: IChromaticMarketFactory,
    public readonly ChromaticMarket: IChromaticMarket,
    public readonly ChromaticRouter: IChromaticRouter,
    public readonly ChromaticLens: ChromaticLens
  ) {
    this.address = signer.address
  }

  async createAccount() {
    let accountAddress = await this.ChromaticRouter['getAccount()']()
    if (accountAddress === ethers.constants.AddressZero) {
      await this.ChromaticRouter.createAccount()
      accountAddress = await this.ChromaticRouter['getAccount()']()
    }
    console.log(`create Account, signer: ${accountAddress}, ${this.signer.address}`)
    this.Account = IChromaticAccount__factory.connect(accountAddress, this.signer)
  }

  async wrapEth(eth: number) {
    await this.WETH9.deposit({ value: parseEther(eth.toString()) })
  }

  async swapEth(eth: number) {
    await this.WETH9.approve(this.SwapRouter.address, ethers.constants.MaxUint256)

    await this.SwapRouter.exactInputSingle({
      tokenIn: this.WETH9.address,
      tokenOut: this.USDC.address,
      // fee: 10000,
      fee: 3000,
      // fee: 500,
      recipient: this.address,
      deadline: Math.ceil(Date.now() / 1000) + 30,
      amountIn: parseEther(eth.toString()),
      amountOutMinimum: 0,
      sqrtPriceLimitX96: 0
    })

    await this.WETH9.approve(this.SwapRouter.address, 0)
  }

  async positions(): Promise<PositionStructOutput[]> {
    const positionIds = await this.Account.getPositionIds(this.ChromaticMarket.address)
    return await this.ChromaticMarket.getPositions(positionIds)
  }

  async openPosition(qty: number, leverage: number, takerMargin: number, makerMargin: number) {
    const decimals = await this.USDC.decimals()
    const _takerMargin = parseUnits(takerMargin.toString(), decimals)
    const _makerMargin = parseUnits(makerMargin.toString(), decimals)

    await this.ChromaticRouter.openPosition(
      this.ChromaticMarket.address,
      parseUnits(qty.toString(), QTY_DECIMALS),
      parseUnits(leverage.toString(), LEVERAGE_DECIMALS),
      _takerMargin,
      _makerMargin,
      _makerMargin // no limit trading fee
    )
  }

  async closePosition(positionId: number) {
    await this.ChromaticRouter.closePosition(
      this.ChromaticMarket.address,
      BigNumber.from(positionId)
    )
  }

  async addLiquidity(feeRate: number, amount: number) {
    const decimals = await this.USDC.decimals()
    await this.ChromaticRouter.addLiquidity(
      this.ChromaticMarket.address,
      parseUnits(feeRate.toString(), FEE_RATE_DECIMALS),
      parseUnits(amount.toString(), decimals),
      this.address
    )
  }

  async claimLiquidity(receiptId: number) {
    await this.ChromaticRouter.claimLiquidity(this.ChromaticMarket.address, receiptId)
  }

  async removeLiquidity(feeRate: number, clbTokenAmount: number) {
    const decimals = await this.USDC.decimals()
    await this.ChromaticRouter.removeLiquidity(
      this.ChromaticMarket.address,
      parseUnits(feeRate.toString(), FEE_RATE_DECIMALS),
      parseUnits(clbTokenAmount.toString(), decimals),
      this.address
    )
  }

  async withdrawLiquidity(receiptId: number) {
    await this.ChromaticRouter.withdrawLiquidity(this.ChromaticMarket.address, receiptId)
  }
}

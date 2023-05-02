import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { ethers } from "ethers"
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
    await this.WETH9.deposit({ value: ethers.utils.parseEther(eth.toString()) })
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
      deadline: (Date.now() / 1000).toFixed() + 30,
      amountIn: ethers.utils.parseEther(eth.toString()),
      amountOutMinimum: 0,
      sqrtPriceLimitX96: 0,
    })

    await this.WETH9.approve(this.SwapRouter.address, 0)
  }
}

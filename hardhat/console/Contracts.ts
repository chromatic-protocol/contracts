import {
  ChromaticLens,
  ChromaticLens__factory,
  ChromaticMarketFactory,
  ChromaticMarketFactory__factory,
  ChromaticRouter,
  ChromaticRouter__factory,
  ChromaticVault,
  ChromaticVault__factory,
  FlashLoanExample,
  FlashLoanExample__factory,
  ICLBToken,
  ICLBToken__factory,
  IChromaticMarket,
  IChromaticMarket__factory,
  IERC20Metadata,
  IERC20Metadata__factory,
  ILiquidator,
  ILiquidator__factory,
  IOracleProvider,
  IOracleProvider__factory,
  ISwapRouter,
  ISwapRouter__factory,
  IWETH9,
  IWETH9__factory,
  KeeperFeePayer,
  KeeperFeePayer__factory,
  Token,
  Token__factory
} from '@chromatic/typechain-types'
import {
  ID_TO_CHAIN_ID,
  SWAP_ROUTER_02_ADDRESSES,
  USDC_ON,
  WETH9
} from '@uniswap/smart-order-router'
import { MaxUint256, Signer, Wallet, parseUnits } from 'ethers'
import gaussian from 'gaussian'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const ARB_GOERLI_SWAP_ROUTER_ADDRESS = '0xF1596041557707B1bC0b3ffB34346c1D9Ce94E86'
const ARB_GOERLI_CHRM_ADDRESS = '0x29A6AC3D416F8Ca85A3df95da209eDBfaF6E522d'

// prettier-ignore
const fees = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, // 0.01% ~ 0.09%, step 0.01%
  10, 20, 30, 40, 50, 60, 70, 80, 90, // 0.1% ~ 0.9%, step 0.1%
  100, 200, 300, 400, 500, 600, 700, 800, 900, // 1% ~ 9%, step 1%
  1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000 // 10% ~ 50%, step 5%
];

export class Contracts {
  private _signer!: Signer
  private _factory!: ChromaticMarketFactory
  private _vault!: ChromaticVault
  private _liquidator!: ILiquidator
  private _router!: ChromaticRouter
  private _lens!: ChromaticLens
  private _keeperFeePayer!: KeeperFeePayer
  private _weth!: IWETH9
  private _usdc!: IERC20Metadata
  private _chrm: Token | undefined
  private _swapRouter!: ISwapRouter

  constructor(public readonly hre: HardhatRuntimeEnvironment) {}

  async connect(privateKey: string | undefined) {
    const { config, network, ethers } = this.hre
    const echainId =
      network.name === 'anvil' ? config.networks.arbitrum_goerli.chainId! : network.config.chainId!
    const chainId = ID_TO_CHAIN_ID(echainId) as keyof typeof WETH9

    this._signer = privateKey
      ? new Wallet(privateKey, ethers.provider)
      : (await ethers.getSigners())[0]

    this._factory = this.connectFactory(await this.addressOf('ChromaticMarketFactory'))
    this._vault = this.connectVault(await this.addressOf('ChromaticVault'))
    this._liquidator = this.connectLiquidator(
      (await this.addressOf('GelatoLiquidator')) || (await this.addressOf('Mate2Liquidator'))
    )
    this._router = this.connectRouter(await this.addressOf('ChromaticRouter'))
    this._lens = this.connectLens(await this.addressOf('ChromaticLens'))
    this._keeperFeePayer = this.connectKeeperFeePayer(await this.addressOf('KeeperFeePayer'))
    this._weth = IWETH9__factory.connect(WETH9[chainId].address, this._signer!)
    this._usdc = this.connectToken(USDC_ON(chainId).address)
    this._chrm =
      echainId === config.networks.arbitrum_goerli.chainId!
        ? Token__factory.connect(ARB_GOERLI_CHRM_ADDRESS, this._signer)
        : undefined

    const swapRouterAddress =
      echainId === config.networks.arbitrum_goerli.chainId!
        ? ARB_GOERLI_SWAP_ROUTER_ADDRESS
        : SWAP_ROUTER_02_ADDRESSES(echainId)
    this._swapRouter = ISwapRouter__factory.connect(swapRouterAddress, this._signer)
  }

  private async addressOf(name: string): Promise<string> {
    return (await this.hre.deployments.get(name)).address
  }

  get signer(): Signer {
    return this._signer
  }

  get factory(): ChromaticMarketFactory {
    return this._factory
  }

  get vault(): ChromaticVault {
    return this._vault
  }

  get liquidator(): ILiquidator {
    return this._liquidator
  }

  get router(): ChromaticRouter {
    return this._router
  }

  get lens(): ChromaticLens {
    return this._lens
  }

  get keeperFeePayer(): KeeperFeePayer {
    return this._keeperFeePayer
  }

  get weth(): IWETH9 {
    return this._weth
  }

  get usdc(): IERC20Metadata {
    return this._usdc
  }

  get chrm(): Token | undefined {
    return this._chrm
  }

  get swapRouter(): ISwapRouter {
    return this._swapRouter
  }

  connectOracleProvider(address: string): IOracleProvider {
    return IOracleProvider__factory.connect(address, this._signer!)
  }

  connectToken(address: string): IERC20Metadata {
    return IERC20Metadata__factory.connect(address, this._signer!)
  }

  connectCLBToken(address: string): ICLBToken {
    return ICLBToken__factory.connect(address, this._signer!)
  }

  connectMarket(address: string): IChromaticMarket {
    return IChromaticMarket__factory.connect(address, this._signer!)
  }

  connectFactory(address: string): ChromaticMarketFactory {
    return ChromaticMarketFactory__factory.connect(address, this._signer)
  }

  connectVault(address: string): ChromaticVault {
    return ChromaticVault__factory.connect(address, this._signer)
  }

  connectLiquidator(address: string): ILiquidator {
    return ILiquidator__factory.connect(address, this._signer)
  }

  connectRouter(address: string): ChromaticRouter {
    return ChromaticRouter__factory.connect(address, this._signer)
  }

  connectLens(address: string): ChromaticLens {
    return ChromaticLens__factory.connect(address, this._signer)
  }

  connectKeeperFeePayer(address: string): KeeperFeePayer {
    return KeeperFeePayer__factory.connect(address, this._signer)
  }

  async addLiquidityWithGaussianDistribution(
    marketAddress: string,
    minAmount: number,
    maxAmount: number
  ) {
    const distribution = gaussian(0, 0.2)

    const market = this.connectMarket(marketAddress)
    if ((await market.settlementToken()) != (await this.chrm!.getAddress())) {
      console.error('invalid settlement token')
      return
    }

    const scale = maxAmount - minAmount
    const decimals = await this.chrm!.decimals()

    const longAmounts = fees.map((_, idx) => {
      const p = distribution.pdf((idx + Math.random()) / fees.length)
      return parseUnits((p * scale + minAmount).toString(), decimals)
    })
    const shortAmounts = fees.map((_, idx) => {
      const p = distribution.pdf((idx + Math.random()) / fees.length)
      return parseUnits((p * scale + minAmount).toString(), decimals)
    })
    const amounts = longAmounts.concat(shortAmounts)

    const totalAmount = amounts.reduce((sum, amount) => sum + amount, 0n)

    const chrmBalance = await this.chrm!.balanceOf(this.signer)
    if (chrmBalance < totalAmount) await (await this.chrm!.faucet(totalAmount - chrmBalance)).wait()
    await (await this.chrm!.approve(this.router, MaxUint256)).wait()

    await (
      await this.router.addLiquidityBatch(
        market,
        this.signer,
        fees.concat(fees.map((fee) => -fee)),
        amounts
      )
    ).wait()
  }

  async getOrDeployFlashLoanExample(): Promise<FlashLoanExample> {
    const deployed = await this.hre.deployments.getOrNull('FlashLoanExample')
    if (deployed) {
      const contract = this.connectFlashLoanExample(deployed.address)
      if ((await contract.lendingPool()) == (await this.vault.getAddress())) {
        return contract
      }
    }

    return await new FlashLoanExample__factory(this._signer).deploy(await this.vault.getAddress())
  }

  connectFlashLoanExample(address: string): FlashLoanExample {
    return FlashLoanExample__factory.connect(address, this._signer)
  }
}

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
  GelatoTest,
  GelatoTest__factory,
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
  Mate2MarketSettlement,
  Mate2MarketSettlement__factory,
  TestSettlementToken,
  TestSettlementToken__factory
} from '@chromatic/typechain-types'
import {
  ID_TO_CHAIN_ID,
  SUPPORTED_CHAINS,
  SWAP_ROUTER_02_ADDRESSES,
  USDC_ON,
  WETH9
} from '@uniswap/smart-order-router'
import { NonceManager, Signer, Wallet, ZeroAddress } from 'ethers'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const SWAP_ROUTER_ADDRESS: { [key: number]: string } = {
  421614: '0xD26b223eeF87B529Fa3cA768DA217183081a4C8E', // FixedPriceSwapRouter
  5000: '0x319B69888b0d11cEC22caA5034e25FfFBDc88421', // mantle AGNI
  5001: '0xe2DB835566F8677d6889ffFC4F3304e8Df5Fc1df' // mantle_testnet AGNI
}

const WETH: { [key: number]: string } = {
  421614: '0x980B62Da83eFf3D4576C647993b0c1D7faf17c73'
}

const WMNT: { [key: number]: string } = {
  5000: '0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8', // mantle
  5001: '0xea12be2389c2254baad383c6ed1fa1e15202b52a' // mantle_testnet
}

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
  private _wmnt!: IWETH9
  private _usdc!: IERC20Metadata
  private _ceth: TestSettlementToken | undefined
  private _cbtc: TestSettlementToken | undefined
  private _swapRouter!: ISwapRouter
  private _marketSettlement: Mate2MarketSettlement | undefined
  private _gelatoTest: GelatoTest | undefined

  constructor(public readonly hre: HardhatRuntimeEnvironment) {}

  async connect(privateKey: string | undefined) {
    const { config, network, ethers } = this.hre
    const echainId: keyof typeof WETH9 =
      network.name === 'anvil'
        ? config.networks.arbitrum_sepolia.chainId!
        : network.name === 'anvil_mantle'
        ? config.networks.mantle_testnet.chainId!
        : network.config.chainId!

    this._signer = new NonceManager(
      privateKey ? new Wallet(privateKey, ethers.provider) : (await ethers.getSigners())[0]
    )

    this._factory = this.connectFactory((await this.addressOf('ChromaticMarketFactory'))!)
    this._vault = this.connectVault((await this.addressOf('ChromaticVault'))!)
    this._liquidator = this.connectLiquidator(
      (await this.addressOf('GelatoLiquidator')) || (await this.addressOf('Mate2Liquidator'))!
    )
    this._router = this.connectRouter((await this.addressOf('ChromaticRouter'))!)
    this._lens = this.connectLens((await this.addressOf('ChromaticLens'))!)
    this._keeperFeePayer = this.connectKeeperFeePayer((await this.addressOf('KeeperFeePayer'))!)

    const cethAddress = await this.addressOf('cETH')
    if (cethAddress) {
      this._ceth = this.connectTestSettlementToken(cethAddress)
    }
    const cbtcAddress = await this.addressOf('cBTC')
    if (cbtcAddress) {
      this._cbtc = this.connectTestSettlementToken(cbtcAddress)
    }

    const swapRouterAddress = SWAP_ROUTER_ADDRESS[echainId] ?? SWAP_ROUTER_02_ADDRESSES(echainId)
    this._swapRouter = ISwapRouter__factory.connect(swapRouterAddress, this._signer)

    this._weth = IWETH9__factory.connect(WETH[echainId] ?? WETH9[echainId].address, this._signer!)

    if (SUPPORTED_CHAINS.includes(echainId)) {
      const chainId = ID_TO_CHAIN_ID(echainId) as keyof typeof WETH9
      this._usdc = this.connectToken(USDC_ON(chainId).address)
    }

    const wmntAddress = WMNT[echainId]
    if (wmntAddress) {
      this._wmnt = IWETH9__factory.connect(wmntAddress, this._signer!)
    }

    const marketSettlementAddress = await this.factory.marketSettlement()
    if (marketSettlementAddress != ZeroAddress) {
      this._marketSettlement = Mate2MarketSettlement__factory.connect(
        marketSettlementAddress,
        this._signer
      )
    }

    const gelatoTestAddress = await this.addressOf('GelatoTest')
    if (gelatoTestAddress) {
      this._gelatoTest = this.connectGelatoTest(gelatoTestAddress)
    }
  }

  private async addressOf(name: string): Promise<string | undefined> {
    return (await this.hre.deployments.getOrNull(name))?.address
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

  get wmnt(): IWETH9 {
    return this._wmnt
  }

  get usdc(): IERC20Metadata {
    return this._usdc
  }

  get ceth(): TestSettlementToken | undefined {
    return this._ceth
  }

  get cbtc(): TestSettlementToken | undefined {
    return this._cbtc
  }

  get swapRouter(): ISwapRouter {
    return this._swapRouter
  }

  get marketSettlement(): Mate2MarketSettlement | undefined {
    return this._marketSettlement
  }

  get gelatoTest(): GelatoTest | undefined {
    return this._gelatoTest
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

  connectTestSettlementToken(address: string): TestSettlementToken {
    return TestSettlementToken__factory.connect(address, this._signer)
  }

  connectGelatoTest(address: string): GelatoTest {
    return GelatoTest__factory.connect(address, this._signer)
  }

  /*
  async addLiquidityWithGaussianDistribution(
    marketAddress: string,
    minAmount: number,
    maxAmount: number
  ) {
    const distribution = gaussian(0, 0.2)

    const market = this.connectMarket(marketAddress)
    if ((await market.settlementToken()) != (await this.ctst!.getAddress())) {
      console.error('invalid settlement token')
      return
    }

    const scale = maxAmount - minAmount
    const decimals = await this.ctst!.decimals()

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

    const ctstBalance = await this.ctst!.balanceOf(this.signer)
    if (ctstBalance < totalAmount)
      await (await this.ctst!.mint(this.signer, totalAmount - ctstBalance)).wait()
    await (await this.ctst!.approve(this.router, MaxUint256)).wait()

    await (
      await this.router.addLiquidityBatch(
        market,
        this.signer,
        fees.concat(fees.map((fee) => -fee)),
        amounts
      )
    ).wait()
  }
  */

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

import { SWAP_ROUTER_02_ADDRESSES, USDC_ARBITRUM_GOERLI, WETH9 } from '@uniswap/smart-order-router'
import { BigNumber, ethers } from 'ethers'
import { extendEnvironment } from 'hardhat/config'
import { lazyFunction, lazyObject } from 'hardhat/plugins'
import {
  IChromaticMarketFactory__factory,
  OracleProviderMock__factory,
  ChromaticLiquidatorMock__factory
} from '../typechain-types'
import { ReplWallet } from './ReplWallet'
import './type-extensions'

const SIGNERS = ['alice', 'bob', 'charlie', 'david', 'eve', 'frank', 'grace', 'heidi']

const ARB_GOERLI_SWAP_ROUTER_ADDRESS = '0xF1596041557707B1bC0b3ffB34346c1D9Ce94E86'

extendEnvironment((hre) => {
  const { config, deployments, network } = hre
  const echainId =
    network.name === 'anvil'
      ? config.networks.arbitrum_one_goerli.chainId!
      : network.config.chainId!

  hre.w = lazyObject(() =>
    SIGNERS.reduce((w, s) => {
      w[s] = undefined
      return w
    }, {})
  )

  hre.initialize = lazyFunction(() => async () => {
    const namedAccounts = await hre.getNamedAccounts()
    const signers = await hre.ethers.getSigners()
    const deployer = signers.find((s) => s.address === namedAccounts.deployer)!

    const { address: marketFactory } = await deployments.get('ChromaticMarketFactory')
    const { address: oracleProvider } = await deployments.get('OracleProviderMock')
    const { address: accountFactory } = await deployments.get('AccountFactory')
    const { address: router } = await deployments.get('ChromaticRouter')

    // set first price
    const _oracleProvider = OracleProviderMock__factory.connect(oracleProvider, deployer)
    await _oracleProvider.increaseVersion(ethers.utils.parseUnits('100', 8))

    await SIGNERS.reduce(async (w, s) => {
      const _w = await w

      const address = namedAccounts[s]
      const signer = signers.find((s) => s.address === address)!
      const wallet = await ReplWallet.create(
        signer,
        {
          weth: WETH9[echainId].address,
          usdc: USDC_ARBITRUM_GOERLI.address,
          swapRouter:
            echainId === config.networks.arbitrum_one_goerli.chainId!
              ? ARB_GOERLI_SWAP_ROUTER_ADDRESS
              : SWAP_ROUTER_02_ADDRESSES(echainId),
          marketFactory,
          oracleProvider,
          accountFactory,
          router
        },
        ['alice', 'bob'].includes(s)
      )
      await prepareWallet(wallet)

      _w[s] = wallet
      return _w
    }, Promise.resolve(hre.w))
  })

  hre.updatePrice = lazyFunction(() => async (price: number) => {
    const { deployer: deployerAddress, gelato: gelatoAddress } = await hre.getNamedAccounts()
    const signers = await hre.ethers.getSigners()
    const deployer = signers.find((s) => s.address === deployerAddress)!
    const gelato = signers.find((s) => s.address === gelatoAddress)!

    const { address: oracleProviderAddress } = await deployments.get('OracleProviderMock')
    const oracleProvider = OracleProviderMock__factory.connect(oracleProviderAddress, deployer)
    await oracleProvider.increaseVersion(ethers.utils.parseUnits(price.toString(), 18))

    const { address: marketFactoryAddress } = await deployments.get('ChromaticMarketFactory')
    const marketFactory = IChromaticMarketFactory__factory.connect(marketFactoryAddress, deployer)

    const marketAddress = await marketFactory.getMarket(
      oracleProvider.address,
      USDC_ARBITRUM_GOERLI.address
    )
    const { address: liquidatorAddress } = await deployments.get('ChromaticLiquidatorMock')
    const liquidator = ChromaticLiquidatorMock__factory.connect(liquidatorAddress, gelato)

    for (const signer of SIGNERS) {
      const w: ReplWallet = hre.w[signer]
      const positionIds = await w.Account.getPositionIds(marketAddress)
      if (positionIds.length == 0) return

      for (const positionId of positionIds) {
        const market = w.ChromaticMarket
        if (await market.checkLiquidation(positionId))
          await liquidator['iquidate(address,uint256,uint256)'](
            market.address,
            positionId,
            BigNumber.from('0') // FIXME
          )
      }
    }
  })
})

async function prepareWallet(wallet: ReplWallet) {
  if ((await wallet.WETH9.balanceOf(wallet.address)).lt(ethers.utils.parseEther('1000'))) {
    await wallet.wrapEth(5000)
  }
  if (
    (await wallet.USDC.balanceOf(wallet.address)).lt(
      ethers.utils.parseUnits('100', await wallet.USDC.decimals())
    )
  ) {
    await wallet.swapEth(1)
  }
}

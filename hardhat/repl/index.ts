import { SWAP_ROUTER_02_ADDRESSES, USDC_ARBITRUM_GOERLI, WETH9 } from '@uniswap/smart-order-router'
import { BigNumber, ethers } from 'ethers'
import { extendEnvironment } from 'hardhat/config'
import { lazyFunction, lazyObject } from 'hardhat/plugins'
import {
  ChromaticLiquidatorMock__factory,
  IChromaticMarketFactory__factory,
  IERC20__factory,
  OracleProviderMock__factory
} from '../../typechain-types'
import { ReplWallet } from './ReplWallet'
import './type-extensions'

const SIGNERS = ['alice', 'bob', 'charlie', 'david', 'eve', 'frank', 'grace', 'heidi']

const ARB_GOERLI_SWAP_ROUTER_ADDRESS = '0xF1596041557707B1bC0b3ffB34346c1D9Ce94E86'

const ORACLE_PROVIDER_DECIMALS = 18

extendEnvironment((hre) => {
  const { config, deployments, network } = hre
  const echainId =
    network.name === 'anvil' ? config.networks.arbitrum_goerli.chainId! : network.config.chainId!

  hre.w = lazyObject(() =>
    SIGNERS.reduce((w, s) => {
      w[s] = undefined
      return w
    }, {})
  )

  hre.showMeTheMoney = lazyFunction(
    () => async (account: string, ethAmount: number, usdcAmount: number) => {
      await hre.network.provider.send('anvil_setBalance', [
        account,
        ethers.utils.parseEther(`${ethAmount}`).toHexString()
      ])

      function fillZero(str: string, width: number) {
        return str.length >= width ? str : new Array(width - str.length + 1).join('0') + str
      }

      function getMappingValueSlot(mappingSlotIndexHex: string, keyHex: string): BigNumber {
        let slotIndex = fillZero(mappingSlotIndexHex.replace('0x', ''), 64)
        let key = fillZero(keyHex.replace('0x', ''), 64) // 32bytes
        const storageKeyHex = ethers.utils.keccak256(`0x${key + slotIndex}`)
        return BigNumber.from(storageKeyHex)
      }

      // StandardArbERC20 _balance slot : 33
      // usdc 0x8fb1e3fc51f3b789ded7557e680551d93ea9d892
      // (found by anvil cache storage json - 1. find ERC20 address, 2. find balance of specific account )
      // "0xe242da282246b923bfd083e3182d8451253d6607471d2241d5255f9eeb794bc2": "0x0000000000000000000000000000000000000000000000000000000001810cd9",
      // await showMeTheMoney('0xaF8de6Fd87fD0b63d758960d55Da250d160F7c90',1000,2000)
      // for (let index = 0; index < 100; index++) {
      //   const slot = getMappingValueSlot(index.toString(), account)
      //   if(slot.toHexString().indexOf('e242da2') > 0){
      //     console.log(index,slot)
      //   }
      // }
      const slot = getMappingValueSlot('33', account)
      console.log(slot.toHexString())
      const usdcAmountInput = BigNumber.from(usdcAmount)
        .mul(10 ** 6)
        .toHexString()
      const usdcAmountInput32Bytes = fillZero(usdcAmountInput.replace('0x', ''), 64)
      await hre.network.provider.send('anvil_setStorageAt', [
        USDC_ARBITRUM_GOERLI.address,
        slot.toHexString(),
        usdcAmountInput32Bytes
      ])
    }
  )

  hre.initialize = lazyFunction(() => async () => {
    const signers = await hre.ethers.getSigners()

    for (let i = 0; i < 10; i++) {
      console.log('set balance to ', ethers.utils.parseEther('10000'), signers[i].address)
      await hre.network.provider.send('anvil_setBalance', [
        signers[i].address,
        ethers.utils.parseEther('10000').toString()
      ])
    }

    const namedAccounts = await hre.getNamedAccounts()
    const deployer = signers.find((s) => s.address === namedAccounts.deployer)!

    const { address: marketFactory } = await deployments.get('ChromaticMarketFactory')
    const { address: oracleProvider } = await deployments.get('OracleProviderMock')
    const { address: router } = await deployments.get('ChromaticRouter')
    const { address: lens } = await deployments.get('ChromaticLens')

    // set first price
    const _oracleProvider = OracleProviderMock__factory.connect(oracleProvider, deployer)
    await _oracleProvider.increaseVersion(ethers.utils.parseUnits('100', ORACLE_PROVIDER_DECIMALS))

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
            echainId === config.networks.arbitrum_goerli.chainId!
              ? ARB_GOERLI_SWAP_ROUTER_ADDRESS
              : SWAP_ROUTER_02_ADDRESSES(echainId),
          marketFactory,
          oracleProvider,
          router,
          lens
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
    await oracleProvider.increaseVersion(
      ethers.utils.parseUnits(price.toString(), ORACLE_PROVIDER_DECIMALS)
    )

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
          await liquidator['liquidate(address,uint256,uint256)'](
            market.address,
            positionId,
            BigNumber.from('0') // FIXME
          )
      }
    }
  })

  hre.currentOracleVersion = lazyFunction(() => async () => {
    const { deployer: deployerAddress, gelato: gelatoAddress } = await hre.getNamedAccounts()
    const signers = await hre.ethers.getSigners()
    const deployer = signers.find((s) => s.address === deployerAddress)!
    const gelato = signers.find((s) => s.address === gelatoAddress)!

    const { address: oracleProviderAddress } = await deployments.get('OracleProviderMock')
    const oracleProvider = OracleProviderMock__factory.connect(oracleProviderAddress, deployer)
    return await oracleProvider.currentVersion()
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

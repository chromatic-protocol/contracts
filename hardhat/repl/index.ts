import * as Token from '@chromatic/deployments/anvil/Token.json'
import {
  ChromaticAccount__factory,
  ChromaticRouter__factory,
  GelatoLiquidatorMock__factory,
  IChromaticMarketFactory__factory,
  IMarketLiquidate__factory,
  IMarketSettle__factory,
  OracleProviderMock__factory
} from '@chromatic/typechain-types'
import { SWAP_ROUTER_02_ADDRESSES, USDC_ARBITRUM_GOERLI, WETH9 } from '@uniswap/smart-order-router'
import chalk from 'chalk'
import { ethers } from 'ethers'
import { extendEnvironment } from 'hardhat/config'
import { lazyFunction, lazyObject } from 'hardhat/plugins'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { ReplWallet } from './ReplWallet'
import './type-extensions'

const SIGNERS = ['alice', 'bob', 'charlie', 'david', 'eve', 'frank', 'grace', 'heidi']

const ARB_GOERLI_SWAP_ROUTER_ADDRESS = '0xF1596041557707B1bC0b3ffB34346c1D9Ce94E86'

const ORACLE_PROVIDER_DECIMALS = 18

extendEnvironment((hre: HardhatRuntimeEnvironment) => {
  const { config, deployments, network } = hre
  const echainId: keyof typeof WETH9 =
    network.name === 'anvil'
      ? config.networks.arbitrum_goerli.chainId!
      : network.name === 'anvil_mantle'
      ? config.networks.mantle_testnet.chainId!
      : network.config.chainId!

  hre.w = lazyObject(() =>
    SIGNERS.reduce((w: { [accountName: string]: any }, s) => {
      w[s] = undefined
      return w
    }, {})
  )

  hre.showMeTheMoney = lazyFunction(
    () => async (account: string, ethAmount: number, erc20Amount: number) => {
      await hre.network.provider.send('anvil_setBalance', [
        account,
        '0x' + ethers.parseEther(`${ethAmount}`).toString(16)
      ])

      console.log(chalk.yellow(`💸 Eth balance charged : ${ethAmount}`))

      function fillZero(str: string, width: number) {
        return str.length >= width ? str : new Array(width - str.length + 1).join('0') + str
      }

      function getMappingValueSlot(mappingSlotIndexHex: string, keyHex: string): bigint {
        let slotIndex = fillZero(mappingSlotIndexHex.replace('0x', ''), 64)
        let key = fillZero(keyHex.replace('0x', ''), 64) // 32bytes
        const storageKeyHex = ethers.keccak256(`0x${key + slotIndex}`)
        return ethers.toBigInt(storageKeyHex)
      }

      async function setSlotBalance(
        address: string,
        slotIndex: number,
        amount: number,
        decimals: number
      ) {
        const slot = getMappingValueSlot(`${slotIndex}`, account)
        const amountWithDecimals = '0x' + (BigInt(amount) * 10n ** BigInt(decimals)).toString(16)
        const amountWithDecimals32Bytes = fillZero(amountWithDecimals.replace('0x', ''), 64)
        await hre.network.provider.send('anvil_setStorageAt', [
          address,
          '0x' + slot.toString(16),
          amountWithDecimals32Bytes
        ])
        console.log(chalk.yellow(`💸 ERC20 balance charged : ${address} ${amount}`))
      }

      await setSlotBalance(USDC_ARBITRUM_GOERLI.address, 33, erc20Amount, 6)
      await setSlotBalance(Token.address, 0, erc20Amount, 18)
    }
  )

  hre.initialize = lazyFunction(() => async () => {
    const signers = await hre.ethers.getSigners()

    for (let i = 0; i < 10; i++) {
      console.log('set balance to ', ethers.parseEther('10000'), signers[i].address)
      await hre.network.provider.send('anvil_setBalance', [
        signers[i].address,
        ethers.parseEther('10000').toString()
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
    await _oracleProvider.increaseVersion(ethers.parseUnits('100', ORACLE_PROVIDER_DECIMALS))

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

    await hre.network.provider.send('evm_setNextBlockTimestamp', [
      '0x' + BigInt(Number(Date.now() / 1000).toFixed()).toString(16)
    ])
  })

  hre.updatePrice = lazyFunction(() => async (price: number) => {
    const { deployer: deployerAddress, gelato: gelatoAddress } = await hre.getNamedAccounts()
    const signers = await hre.ethers.getSigners()
    const deployer = signers.find((s) => s.address === deployerAddress)!
    const gelato = signers.find((s) => s.address === gelatoAddress)!

    const { address: oracleProviderAddress } = await deployments.get('OracleProviderMock')
    const oracleProvider = OracleProviderMock__factory.connect(oracleProviderAddress, deployer)
    await oracleProvider.increaseVersion(
      ethers.parseUnits(price.toString(), ORACLE_PROVIDER_DECIMALS)
    )

    const { address: marketFactoryAddress } = await deployments.get('ChromaticMarketFactory')
    const marketFactory = IChromaticMarketFactory__factory.connect(marketFactoryAddress, deployer)

    const marketAddresses = await marketFactory.getMarkets()
    const { address: liquidatorAddress } = await deployments.get('GelatoLiquidatorMock')
    const liquidator = GelatoLiquidatorMock__factory.connect(liquidatorAddress, gelato)

    const { address: router } = await deployments.get('ChromaticRouter')
    const routerContract = ChromaticRouter__factory.connect(router, deployer)
    const routerFilter = routerContract.filters.AccountCreated()
    const accounts = (await routerContract.queryFilter(routerFilter)).map((e) => e.args.account)

    for (const marketAddress of marketAddresses) {
      const market = IMarketLiquidate__factory.connect(marketAddress, deployer)
      const marketSettle = IMarketSettle__factory.connect(marketAddress, deployer)
      await marketSettle.settleAll()
      for (const account of accounts) {
        const positionIds = await ChromaticAccount__factory.connect(
          account,
          deployer
        ).getPositionIds(marketAddress)

        if (positionIds.length == 0) continue

        for (const positionId of positionIds) {
          if (await market.checkLiquidation(positionId))
            await liquidator['liquidate(address,uint256,uint256)'](
              await market.getAddress(),
              positionId,
              0n
            )
        }
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
  if ((await wallet.WETH9.balanceOf(wallet.address)) < ethers.parseEther('1000')) {
    await wallet.wrapEth(5000)
  }
  if (
    (await wallet.USDC.balanceOf(wallet.address)) <
    ethers.parseUnits('100', await wallet.USDC.decimals())
  ) {
    await wallet.swapEth(1)
  }
}

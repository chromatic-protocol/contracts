import { WETH9 } from '@uniswap/sdk-core'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import { parseEther } from 'viem'
import { FixedPriceSwapRouter__factory, IWETH9__factory } from '../../typechain-types'

const WETH: { [key: number]: string } = {
  421614: '0x980B62Da83eFf3D4576C647993b0c1D7faf17c73'
}

task('fixed-price-swap-router:set-whitelist').setAction(
  async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment): Promise<any> => {
    const { deployments, ethers } = hre
    const signer = (await ethers.getSigners())[0]

    const fixedPriceSwapRouterDeployment = await deployments.getOrNull('FixedPriceSwapRouter')
    if (fixedPriceSwapRouterDeployment) {
      const fixedPriceSwapRouter = FixedPriceSwapRouter__factory.connect(
        fixedPriceSwapRouterDeployment.address,
        signer
      )

      const { address: keeperFeePayerAddress } = await deployments.get('KeeperFeePayer')
      await fixedPriceSwapRouter.addWhitelistedClient(keeperFeePayerAddress)
    }
  }
)

task('fixed-price-swap-router:deposit')
  .addPositionalParam('amount')
  .setAction(async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment): Promise<any> => {
    const { deployments, ethers, network } = hre
    const signer = (await ethers.getSigners())[0]

    const { address: fixedPriceSwapRouterAddress } = await deployments.get('FixedPriceSwapRouter')

    const weth = IWETH9__factory.connect(
      WETH[network.config.chainId!] ?? WETH9[network.config.chainId!].address,
      signer
    )

    const amount = parseEther(taskArgs.amount)
    await weth.deposit({ value: amount })
    await weth.transfer(fixedPriceSwapRouterAddress, amount)
  })

task('fixed-price-swap-router:set-price').setAction(
  async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment): Promise<any> => {
    const { deployments, ethers, network } = hre
    const signer = (await ethers.getSigners())[0]

    const { address: fixedPriceSwapRouterAddress } = await deployments.get('FixedPriceSwapRouter')
    const fixedPriceSwapRouter = FixedPriceSwapRouter__factory.connect(
      fixedPriceSwapRouterAddress,
      signer
    )

    const { address: cETH } = await deployments.get('cETH')
    const { address: cBTC } = await deployments.get('cBTC')
    await fixedPriceSwapRouter.setEthPriceInToken(cETH, parseEther('1000'))
    await fixedPriceSwapRouter.setEthPriceInToken(cBTC, parseEther('100'))
  }
)

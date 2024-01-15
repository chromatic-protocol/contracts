import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import { parseEther } from 'viem'
import { FixedPriceSwapRouter__factory, IERC20__factory } from '../../typechain-types'

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

    const amount = parseEther(taskArgs.amount)
    await signer.sendTransaction({ to: fixedPriceSwapRouterAddress, value: amount })
  })

task('fixed-price-swap-router:withdraw').setAction(
  async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment): Promise<any> => {
    const { deployments, ethers, network } = hre
    const signer = (await ethers.getSigners())[0]

    const { address: fixedPriceSwapRouterAddress } = await deployments.get('FixedPriceSwapRouter')
    const fixedPriceSwapRouter = FixedPriceSwapRouter__factory.connect(
      fixedPriceSwapRouterAddress,
      signer
    )

    const weth = IERC20__factory.connect(await fixedPriceSwapRouter.WETH9(), signer)
    const balance = await weth.balanceOf(fixedPriceSwapRouter)
    await fixedPriceSwapRouter.withdraw(weth, balance)
  }
)

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

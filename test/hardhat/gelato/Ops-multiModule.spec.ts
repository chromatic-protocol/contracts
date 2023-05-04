// import { deploy as deployFakeTokens } from '@usum/test/hardhat/fake_token/deploy'
import { deploy } from '@usum/test/hardhat/gelato/deploy'
import {
  encodeResolverArgs,
  encodeTimeArgs,
  fastForwardTime,
  getTaskId,
  getTimeStampNow,
  Module,
  ModuleData
} from '@usum/test/hardhat/gelato/utils'
import { CounterResolver, CounterWL, IERC20Metadata, Automate, OpsProxy, Token } from '@usum/typechain-types'
import { Signer } from '@ethersproject/abstract-signer'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect, use } from 'chai'
import { ethers } from 'hardhat'
import { hardhatErrorPrettyPrint } from '../utils'


const FEE = ethers.utils.parseEther('0.1')
const INTERVAL = 7 * 60


async function fixture() {
  return await hardhatErrorPrettyPrint(async () => {
    // const { fETH } = await deployFakeTokens()
    const factory = await ethers.getContractFactory('Token')
    const fETH = await factory.deploy('eth','ETH') as Token; 
    const { gelato, taskTreasury, opsProxyFactory, automate } = await deploy()

    const counter = await (await ethers.getContractFactory('CounterWL')).deploy()
    const counterResolver = await (
      await ethers.getContractFactory('CounterResolver')
    ).deploy(counter.address)

    const [, user] = await ethers.getSigners()
    const userAddress = user.address

    // faucet
    const initialAmount = ethers.utils.parseEther('100')
    await fETH.connect(user).faucet(initialAmount)
    await fETH.connect(user).approve(taskTreasury.address, ethers.constants.MaxUint256)

    // deposit funds
    const depositAmount = ethers.utils.parseEther('10')
    await taskTreasury.connect(user).depositFunds(user.address, fETH.address, depositAmount)

    // deploy proxy
    await opsProxyFactory.connect(user).deploy()
    const [proxyAddress] = await opsProxyFactory.getProxyOf(userAddress)
    const opsProxy = await ethers.getContractAt('OpsProxy', proxyAddress)

    // whitelist proxy on counter
    await counter.setWhitelist(opsProxy.address, true)

    return {
      gelato,
      user,
      userAddress,
      fETH,
      taskTreasury,
      opsProxyFactory,
      opsProxy,
      automate,
      counter,
      counterResolver
    }
  })
}

describe('Automate multi module test', function () {
  let gelato: Signer
  let fETH: IERC20Metadata
  let automate: Automate
  let counter: CounterWL
  let counterResolver: CounterResolver
  let opsProxy: OpsProxy

  let user: Signer
  let userAddress: string

  let taskId: string
  let execSelector: string
  let moduleData: ModuleData
  let timeArgs: string
  let resolverArgs: string
  let startTime: number

  beforeEach(async function () {
    ;({ gelato, user, userAddress, fETH, opsProxy, ops: automate, counter, counterResolver } =
      await loadFixture(fixture))

    // create task
    const resolverData = counterResolver.interface.encodeFunctionData('checker')
    resolverArgs = encodeResolverArgs(counterResolver.address, resolverData)

    startTime = (await getTimeStampNow()) + INTERVAL
    timeArgs = encodeTimeArgs(startTime, INTERVAL)
    execSelector = counter.interface.getSighash('increaseCount')
    moduleData = {
      modules: [Module.RESOLVER, Module.TIME, Module.PROXY, Module.SINGLE_EXEC],
      args: [resolverArgs, timeArgs, '0x', '0x']
    }

    taskId = getTaskId(userAddress, counter.address, execSelector, moduleData, fETH.address)

    await automate.connect(user).createTask(counter.address, execSelector, moduleData, fETH.address)

    // whitelist proxy on counter
    expect(await counter.whitelisted(opsProxy.address)).to.be.true
  })

  it('getTaskId', async () => {
    const thisTaskId = await automate['getTaskId(address,address,bytes4,(uint8[],bytes[]),address)'](
      userAddress,
      counter.address,
      execSelector,
      moduleData,
      fETH.address
    )

    const expectedTaskId = taskId

    expect(thisTaskId).to.be.eql(expectedTaskId)
  })

  it('task created', async () => {
    const taskIds = await automate.getTaskIdsByUser(userAddress)
    expect(taskIds).include(taskId)
  })

  it('time initialised', async () => {
    const time = await automate.timedTask(taskId)

    expect(time.nextExec).to.be.eql(ethers.BigNumber.from(startTime))
    expect(time.interval).to.be.eql(ethers.BigNumber.from(INTERVAL))
  })

  it('wrong module order', async () => {
    moduleData = {
      modules: [Module.RESOLVER, Module.SINGLE_EXEC, Module.TIME, Module.PROXY],
      args: [resolverArgs, '0x', timeArgs, '0x']
    }

    await expect(
      automate.connect(user).createTask(counter.address, execSelector, moduleData, fETH.address)
    ).to.be.revertedWith('Automate._validModules: Asc only')
  })

  it('duplicate modules', async () => {
    moduleData = {
      modules: [Module.RESOLVER, Module.RESOLVER],
      args: [resolverArgs, resolverArgs]
    }

    await expect(
      automate.connect(user).createTask(counter.address, execSelector, moduleData, fETH.address)
    ).to.be.revertedWith('Automate._validModules: Asc only')
  })

  it('no modules', async () => {
    await counter.setWhitelist(automate.address, true)
    expect(await counter.whitelisted(automate.address)).to.be.true
    moduleData = { modules: [], args: [] }
    const execData = counter.interface.encodeFunctionData('increaseCount', [10])

    await automate.connect(user).createTask(counter.address, execData, moduleData, fETH.address)

    const countBefore = await counter.count()

    await execute(true)

    const countAfter = await counter.count()
    expect(countAfter).to.be.gt(countBefore)
  })

  it('exec - time should revert', async () => {
    await expect(execute(true)).to.be.revertedWith('Automate.preExecCall: TimeModule: Too early')
  })

  it('exec', async () => {
    await fastForwardTime(INTERVAL)
    const countBefore = await counter.count()

    await execute(true)

    const countAfter = await counter.count()
    expect(countAfter).to.be.gt(countBefore)

    const time = await automate.timedTask(taskId)
    expect(time.nextExec).to.be.eql(ethers.BigNumber.from(0))

    const taskIds = await automate.getTaskIdsByUser(userAddress)
    expect(taskIds).to.not.include(taskId)
  })

  const execute = async (revertOnFailure: boolean) => {
    await hardhatErrorPrettyPrint(async () => {
      const [, execData] = await counterResolver.checker()

      await automate
        .connect(gelato)
        .exec(
          userAddress,
          counter.address,
          execData,
          moduleData,
          FEE,
          fETH.address,
          false,
          revertOnFailure
        )
    })
  }
})

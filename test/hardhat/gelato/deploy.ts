import { Module } from '@usum/test/hardhat/gelato/utils'
import { logDeployed } from '@usum/test/hardhat/log-utils'
import { Automate, OpsProxy, TaskTreasuryUpgradable } from '@usum/typechain-types'
import { deployments, ethers, getNamedAccounts } from 'hardhat'
import { OpsProxyFactory } from '@usum/typechain-types/contracts/mocks/gelato/opsProxy/OpsProxyFactory'

async function deployTaskTreasury(gelato: string): Promise<TaskTreasuryUpgradable> {
  const factory = await ethers.getContractFactory('TaskTreasury')
  const oldTreasury = await factory.deploy(gelato)
  logDeployed('TaskTreasury', oldTreasury.address)

  const { deployer } = await getNamedAccounts()
  const maxFee = ethers.utils.parseEther('0')

  const { address } = await deployments.deploy('TaskTreasuryUpgradable', {
    from: deployer,
    proxy: {
      proxyContract: 'EIP173ProxyWithCustomReceive',
      owner: deployer,
      execute: {
        init: {
          methodName: 'initialize',
          args: [maxFee]
        }
      }
    },
    args: [oldTreasury.address]
  })

  const taskTreasury = await ethers.getContractAt('TaskTreasuryUpgradable', address)
  logDeployed('TaskTreasuryUpgradable', taskTreasury.address)
  return taskTreasury
}

async function deployOps(gelato: string, taskTreasury: TaskTreasuryUpgradable): Promise<Automate> {
  const { deployer } = await getNamedAccounts()
  const { address } = await deployments.deploy('Automate', {
    from: deployer,
    proxy: { owner: deployer },
    args: [gelato, taskTreasury.address]
  })
  const ops = await ethers.getContractAt('Automate', address)
  logDeployed('Automate', ops.address)
  return ops
}

async function deployOpsProxy(ops: Automate): Promise<OpsProxy> {
  const factory = await ethers.getContractFactory('OpsProxy')
  const opsProxy = await factory.deploy(ops.address)
  logDeployed('OpsProxy', opsProxy.address)
  return opsProxy
}
async function deployOpsProxyFactory(
  automate: Automate,
  opsProxy: OpsProxy
): Promise<OpsProxyFactory> {
  const { deployer } = await getNamedAccounts()
  const { address } = await deployments.deploy('OpsProxyFactory', {
    from: deployer,
    proxy: {
      proxyContract: 'EIP173Proxy',
      owner: deployer,
      execute: {
        init: {
          methodName: 'initialize',
          args: [opsProxy.address]
        }
      }
    },
    args: [automate.address]
  })
  const opsProxyFactory = await ethers.getContractAt('OpsProxyFactory', address)
  logDeployed('OpsProxyFactory', opsProxyFactory.address)
  return opsProxyFactory
}

export async function deploy() {
  const { gelato } = await getNamedAccounts()
  console.log('gelato ', gelato)
  const taskTreasury = await deployTaskTreasury(gelato)
  const automate = await deployOps(gelato, taskTreasury)
  const opsProxy = await deployOpsProxy(automate)
  const opsProxyFactory = await deployOpsProxyFactory(automate, opsProxy)

  const resolverModule = await (await ethers.getContractFactory('ResolverModule')).deploy()
  logDeployed('resolverModule', resolverModule.address)
  const timeModule = await (await ethers.getContractFactory('TimeModule')).deploy()
  logDeployed('timeModule', timeModule.address)
  const proxyModule = await (
    await ethers.getContractFactory('ProxyModule')
  ).deploy(opsProxyFactory.address)
  logDeployed('proxyModule', proxyModule.address)
  const singleExecModule = await (await ethers.getContractFactory('SingleExecModule')).deploy()
  logDeployed('singleExecModule', singleExecModule.address)

  await taskTreasury.updateWhitelistedService(automate.address, true)
  await automate.setModule(
    [Module.RESOLVER, Module.TIME, Module.PROXY, Module.SINGLE_EXEC],
    [resolverModule.address, timeModule.address, proxyModule.address, singleExecModule.address]
  )

  return {
    gelato: await ethers.getSigner(gelato),
    taskTreasury,
    opsProxyFactory,
    automate
  }
}

export async function resolverTestDeploy() {
  const { deployer } = await getNamedAccounts()
  console.log('deployer', deployer)

  const { address: testCountResolverAddress } = await deployments.deploy('CountTaskResolver', {
    from: deployer,
    args: []
  })

  const { address: testCountTaskAddress } = await deployments.deploy('IncreaseCountTaskTest', {
    from: deployer,
    args: [
      '0xc1C6805B857Bef1f412519C4A842522431aFed39', // goeril ops contract address
      deployer,
      testCountResolverAddress
    ]
  })

  const { address: signleIncreaseCountTaskAddress } = await deployments.deploy(
    'SignleIncreaseCountTaskTest',
    {
      from: deployer,
      args: [
        '0xc1C6805B857Bef1f412519C4A842522431aFed39', // goeril ops contract address
        deployer,
        testCountResolverAddress
      ]
    }
  )
  console.log('contracts deployed')
  const testCountTask = await ethers.getContractAt('IncreaseCountTaskTest', testCountTaskAddress)
  const signleCountTask = await ethers.getContractAt(
    'SignleIncreaseCountTaskTest',
    signleIncreaseCountTaskAddress
  )

  return {
    testCountTask,
    signleCountTask
  }

  // console.log(depositResult)
}

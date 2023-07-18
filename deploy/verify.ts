import { HardhatRuntimeEnvironment } from 'hardhat/types'

export async function verify(hre: HardhatRuntimeEnvironment, args: any) {
  if (hre.network.name != 'anvil') {
    try {
      await hre.run('verify:verify', args)
    } catch (e) {
      console.error(e)
    }
  }
}

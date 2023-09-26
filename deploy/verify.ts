import { HardhatRuntimeEnvironment } from 'hardhat/types'

export async function verify(hre: HardhatRuntimeEnvironment, args: any) {
  if (hre.network.name != 'anvil') {
    for (let i = 0; i < 5; i++) {
      try {
        await hre.run('verify:verify', args)
        return
      } catch (e) {
        console.error(e)
      }
    }
  }
}

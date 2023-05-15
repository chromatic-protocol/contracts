import { deployContract, hardhatErrorPrettyPrint } from "../../utils"
import { USUMLens } from "@usum/typechain-types"

export async function deploy() {
  return hardhatErrorPrettyPrint(async () => {
   return await deployContract<USUMLens>('USUMLens')
  })
}

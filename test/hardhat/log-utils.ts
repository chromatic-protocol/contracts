import chalk from 'chalk'
import boxen from 'boxen'
import fs from 'fs';
export function printLogo() {
  console.log(
    boxen(
      `
  ${chalk.hex('#5EAFC2')('██╗   ██╗███████╗██╗   ██╗███╗   ███╗    ████████╗███████╗███████╗████████╗')}
  ${chalk.hex('#4CC4C5')('██║   ██║██╔════╝██║   ██║████╗ ████║    ╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝')}
  ${chalk.hex('#58D7BA')('██║   ██║███████╗██║   ██║██╔████╔██║       ██║   █████╗  ███████╗   ██║   ')}
  ${chalk.hex('#82E6A3')('██║   ██║╚════██║██║   ██║██║╚██╔╝██║       ██║   ██╔══╝  ╚════██║   ██║   ')}
  ${chalk.hex('#BAF288')('╚██████╔╝███████║╚██████╔╝██║ ╚═╝ ██║       ██║   ███████╗███████║   ██║   ')}
  ${chalk.hex('#F9F871')(' ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝     ╚═╝       ╚═╝   ╚══════╝╚══════╝   ╚═╝   ')}
`,
      { padding: 1 }
    )
  )
}

export function logDeployed(contractName: string, address: string) {
  console.log(chalk.grey(`\t${contractName} deployed :`), chalk.green(address))
}

export function logGreen(message?: any, ...optionalParams: any[]) {
  console.log(chalk.green(message), ...optionalParams.map((param) => chalk.green(param)))
}

export function logYellow(message?: any, ...optionalParams: any[]) {
  console.log(chalk.yellow(message), ...optionalParams.map((param) => chalk.yellow(param)))
}

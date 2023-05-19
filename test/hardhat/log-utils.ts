import chalk from "chalk";
import boxen from "boxen";
import fs from "fs";
import { BigNumber } from "ethers";
import { assert } from "console";
export function printLogo() {
  console.log(
    boxen(
      `
  ${chalk.hex("#5EAFC2")(
    "██╗   ██╗███████╗██╗   ██╗███╗   ███╗    ████████╗███████╗███████╗████████╗"
  )}
  ${chalk.hex("#4CC4C5")(
    "██║   ██║██╔════╝██║   ██║████╗ ████║    ╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝"
  )}
  ${chalk.hex("#58D7BA")(
    "██║   ██║███████╗██║   ██║██╔████╔██║       ██║   █████╗  ███████╗   ██║   "
  )}
  ${chalk.hex("#82E6A3")(
    "██║   ██║╚════██║██║   ██║██║╚██╔╝██║       ██║   ██╔══╝  ╚════██║   ██║   "
  )}
  ${chalk.hex("#BAF288")(
    "╚██████╔╝███████║╚██████╔╝██║ ╚═╝ ██║       ██║   ███████╗███████║   ██║   "
  )}
  ${chalk.hex("#F9F871")(
    " ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝     ╚═╝       ╚═╝   ╚══════╝╚══════╝   ╚═╝   "
  )}
`,
      { padding: 1 }
    )
  );
}

export function logDeployed(contractName: string, address: string) {
  console.log(chalk.grey(`\t${contractName} deployed :`), chalk.green(address));
}

export function logGreen(message?: any, ...optionalParams: any[]) {
  console.log(
    chalk.green(message),
    ...optionalParams.map((param) => chalk.green(param))
  );
}

export function logYellow(message?: any, ...optionalParams: any[]) {
  console.log(
    chalk.yellow(message),
    ...optionalParams.map((param) => chalk.yellow(param))
  );
}

export function logLiquidity(
  totalMargins: BigNumber[],
  unusedMargins: BigNumber[]
) {
  assert(totalMargins.length === unusedMargins.length)
  const stepPer = 20;
  const maxMargin = totalMargins.reduce((a, b) => (a < b ? b : a));

  const totalsQuartile = totalMargins.map((e) =>
    e.mul(stepPer).div(maxMargin).toNumber()
  );
  const unusedsQuartile = unusedMargins.map((e) =>
    e.mul(stepPer).div(maxMargin).toNumber()
  );

  // console.log(totals20Quartile)
  // console.log(unuseds20Quartile)
  for (let i = 0; i < totalsQuartile.length; i++) {
    const total = totalsQuartile[i];
    const unused = unusedsQuartile[i];
  }

  let result = "";
  const unusedColors = [
    "#9d67d0",
    "#9c66d1",
    "#9b65d2",
    "#9a65d4",
    "#9964d5",
    "#9763d6",
    "#9663d7",
    "#9562d8",
    "#9461da",
    "#9261db",
    "#9160dc",
    "#8f5fde",
    "#8e5fdf",
    "#8c5ee0",
    "#8a5ee1",
    "#885de3",
    "#875ce4",
    "#855ce5",
    "#835be7",
    "#815be8",
    "#7f5aea",
    "#7c5aeb",
    "#7a59ec",
    "#7759ee",
    "#7558ef",
    "#7258f1",
    "#6f58f2",
    "#6c57f3",
    "#6957f5",
    "#6657f6",
    "#6256f8",
    "#5f56f9",
    "#5b56fb",
    "#5755fc",
    "#5255fe",
    "#4d55ff",
    "#f4987b",
    "#f5997b",
    "#f59a7b",
    "#f69b7a",
    "#f69c7a",
    "#f79d7a",
    "#f79f7a",
    "#f8a07a",
    "#f8a179",
    "#f9a279",
    "#f9a379",
    "#faa479",
    "#faa579",
    "#faa679",
    "#fba878",
    "#fba978",
    "#fbaa78",
    "#fcab78",
    "#fcac78",
    "#fcad78",
    "#fdaf78",
    "#fdb078",
    "#fdb178",
    "#fdb278",
    "#feb378",
    "#feb577",
    "#feb677",
    "#feb777",
    "#feb877",
    "#feba78",
    "#ffbb78",
    "#ffbc78",
    "#ffbd78",
    "#ffbf78",
    "#ffc078",
    "#ffc178",
  ];

  const totalColors = [
    "#bfa7d5",
    "#bfa7d6",
    "#bfa7d7",
    "#bea7d8",
    "#bea7d9",
    "#bea7db",
    "#bda7dc",
    "#bda7dd",
    "#bda7de",
    "#bca7df",
    "#bca7e0",
    "#bba7e1",
    "#bba7e3",
    "#baa7e4",
    "#baa7e5",
    "#b9a7e6",
    "#b8a7e7",
    "#b8a7e9",
    "#b7a7ea",
    "#b6a7eb",
    "#b5a7ec",
    "#b5a7ed",
    "#b4a7ef",
    "#b3a7f0",
    "#b2a7f1",
    "#b1a7f2",
    "#b0a8f4",
    "#afa8f5",
    "#aea8f6",
    "#ada8f7",
    "#aba8f9",
    "#aaa8fa",
    "#a9a8fb",
    "#a8a9fc",
    "#a6a9fe",
    "#a5a9ff",
    "#efbaad",
    "#f0bbae",
    "#f0bdae",
    "#f0beaf",
    "#f1c0b0",
    "#f1c1b1",
    "#f2c2b2",
    "#f2c4b3",
    "#f3c5b4",
    "#f3c7b4",
    "#f4c8b5",
    "#f4cab6",
    "#f5cbb7",
    "#f5ccb8",
    "#f5ceb9",
    "#f6cfba",
    "#f6d1bc",
    "#f7d2bd",
    "#f7d3be",
    "#f7d5bf",
    "#f8d6c0",
    "#f8d8c1",
    "#f9d9c2",
    "#f9dac4",
    "#f9dcc5",
    "#faddc6",
    "#fadfc8",
    "#fbe0c9",
    "#fbe1ca",
    "#fbe3cc",
    "#fce4cd",
    "#fce6ce",
    "#fde7d0",
    "#fde8d1",
    "#feead3",
    "#feebd4",
  ];

  for (let step = stepPer; step > 0; step--) {
    // const element = array[i];
    let stepLine = "";
    for (let i = 0; i < totalsQuartile.length; i++) {
      const total = totalsQuartile[i];
      const unused = unusedsQuartile[i];
      const color = unused >= step ? unusedColors[i] : totalColors[i];

      stepLine += total >= step ? chalk.hex(color)("█") : " ";
    }
    result += `${stepLine}\n`;
  }

  console.log(result);
}

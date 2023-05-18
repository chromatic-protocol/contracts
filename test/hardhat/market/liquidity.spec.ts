import { expect } from "chai";
import { ethers } from "hardhat";
import { prepareMarketTest, helpers } from "./testHelper";
import { BigNumber, ContractTransaction } from "ethers";
import { logLiquidity } from "../log-utils";

describe("market test", async function () {
  const oneEther = ethers.utils.parseEther("1");

  // prettier-ignore
  const fees = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, // 0.01% ~ 0.09%, step 0.01%
  10, 20, 30, 40, 50, 60, 70, 80, 90, // 0.1% ~ 0.9%, step 0.1%
  100, 200, 300, 400, 500, 600, 700, 800, 900, // 1% ~ 9%, step 1%
  1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000 // 10% ~ 50%, step 5%
];
  const totalFees = fees
    .map((fee) => -fee)
    .reverse()
    .concat(fees);

  let testData: Awaited<ReturnType<typeof prepareMarketTest>>;

  before(async () => {
    testData = await prepareMarketTest();
  });

  it("change oracle price ", async () => {
    const { owner, oracleProvider } = testData;
    const { version, timestamp, price } = await oracleProvider.currentVersion();
    await oracleProvider
      .connect(owner)
      .increaseVersion(ethers.utils.parseEther("100"), { from: owner.address });
    const { version: nextVersion, price: nextPrice } =
      await oracleProvider.currentVersion();
    console.log("prev", version, price);
    console.log("after update", nextVersion, nextPrice);
    expect(nextVersion).to.equal(version.add(1));
    expect(nextPrice).to.equal(ethers.utils.parseEther("100"));
  });

  it("add/remove liquidity", async () => {
    const { market, usumRouter, tester, oracleProvider, settlementToken } =
      testData;
    const { addLiquidityTx } = helpers(testData);
    const amount = ethers.utils.parseEther("100");
    const feeSlotKey = 1;

    const expectedLiquidity = await market.calculateLiquidity(
      feeSlotKey,
      amount
    );

    await expect(addLiquidityTx(amount, feeSlotKey)).to.changeTokenBalance(
      settlementToken,
      tester.address,
      amount.mul(-1)
    );
    expect(await market.totalSupply(feeSlotKey)).to.equal(expectedLiquidity);

    const removeLiqAmount = amount.div(2);

    const expectedAmount = await market.calculateAmount(
      feeSlotKey,
      removeLiqAmount
    );

    await (
      await market.connect(tester).setApprovalForAll(usumRouter.address, true)
    ).wait();

    await expect(
      usumRouter.connect(tester).removeLiquidity(
        market.address,
        feeSlotKey,
        removeLiqAmount,
        0, // amountMin
        tester.address,
        ethers.constants.MaxUint256 // deadline
      )
    ).to.changeTokenBalance(settlementToken, tester, expectedAmount);

    expect(await market.totalSupply(feeSlotKey)).to.equal(removeLiqAmount);
  });

  it("print liquidity", async () => {
    const { addLiquidityTx } = helpers(testData);

    const txs: Promise<any>[] = [];

    for (let i = 0; i < fees.length; i++) {
      const amount = oneEther.add(oneEther.div(20).mul(fees.length - i));
      txs.push(addLiquidityTx(amount, fees[i]));
      txs.push(addLiquidityTx(amount, -fees[i]));

      // address market,
      // int224 qty,
      // uint32 leverage,
      // uint256 takerMargin,
      // uint256 makerMargin,
      // uint256 maxAllowableTradingFee,
      // uint256 deadline
    }

    await Promise.all(txs);

    // await (
    //   await testData.traderRouter.openPosition(
    //     testData.market.address,
    //     1,
    //     oneEther.mul(50),
    //     oneEther.div(100), // losscut 1 token
    //     oneEther.mul(100), // profit stop 10 token,
    //     ethers.constants.MaxUint256, // maxAllowFee (1% * makerMargin)
    //     ethers.constants.MaxUint256
    //   )
    // ).wait();
    // await (
    //   await testData.traderRouter.openPosition(
    //     testData.market.address,
    //     -1,
    //     oneEther.mul(30),
    //     oneEther.div(100), // losscut 1 token
    //     oneEther.mul(100), // profit stop 10 token,
    //     ethers.constants.MaxUint256, // maxAllowFee (1% * makerMargin)
    //     ethers.constants.MaxUint256
    //   )
    // ).wait();

    // const totals: BigNumber[] = [];
    // const unuseds: BigNumber[] = [];
    // for (let i = 0; i < 72; i++) {
    //   totals.push(oneEther.mul(Math.floor((Math.random() + 1) * 99 + 1)));
    //   unuseds.push(totals[i].div(Math.floor(Math.random() * 3 + 1)));
    // }
    // logLiquidity(totals, unuseds);

    const totalMargins = await testData.market.getSlotMarginsTotal(totalFees);
    const unusedMargins = await testData.market.getSlotMarginsTotal(totalFees);


    logLiquidity(totalMargins, unusedMargins);
  });
});

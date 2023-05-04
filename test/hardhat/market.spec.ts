import {
  OracleProviderMock,
  USUMMarket,
  USUMMarketFactory,
  Token,
  AccountFactory,
  USUMRouter,
  KeeperFeePayerMock,
  USUMLiquidator,
} from "../../typechain-types";
import { ethers } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deploy as marketDeploy } from "./deployMarket";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { BigNumber } from "ethers";
import { logYellow } from "./log-utils";

describe("market test", async function () {
  // start anvil & deploy contract
  // current oracle view
  // set oracle price -> return oracle version을 포함한 어떤 정보
  // add/remove liquidity
  // open/close position
  // execute keeper

  let oracleProvider: OracleProviderMock;
  let marketFactory: USUMMarketFactory;
  let settlementToken: Token;
  let market: USUMMarket;
  let accountFactory: AccountFactory;
  let usumRouter: USUMRouter;
  let owner: SignerWithAddress;
  let tester: SignerWithAddress;
  let trader: SignerWithAddress;
  let liquidator: USUMLiquidator;
  let keeperFeePayer: KeeperFeePayerMock;

  before(async () => {
    ({
      marketFactory,
      keeperFeePayer,
      liquidator,
      oracleProvider,
      market,
      usumRouter,
      accountFactory,
      settlementToken,
    } = await loadFixture(marketDeploy));
    [owner, tester, trader] = await ethers.getSigners();
    console.log("owner", owner.address);

    const marketAddress = await marketFactory.getMarket(
      oracleProvider.address,
      settlementToken.address
    );
    market = await ethers.getContractAt("USUMMarket", marketAddress);

    await faucet(tester);
    await faucet(trader);
  });

  async function faucet(account: SignerWithAddress) {
    const faucetTx = await settlementToken
      .connect(account)
      .faucet(ethers.utils.parseEther("10000"));
    await faucetTx.wait();
  }

  it("change oracle price ", async () => {
    const { version, timestamp, price } = await oracleProvider.currentVersion();
    const balance = await owner.getBalance();
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

  async function addLiquidity(_amount?: BigNumber, _feeSlotKey?: number) {
    const approveTx = await settlementToken
      .connect(tester)
      .approve(usumRouter.address, ethers.constants.MaxUint256);
    await approveTx.wait();

    const amount = _amount ?? ethers.utils.parseEther("100");
    const feeSlotKey = _feeSlotKey ?? 1;

    const addLiqTx = await usumRouter.connect(tester).addLiquidity(
      oracleProvider.address,
      settlementToken.address,
      feeSlotKey,
      amount,
      tester.address,
      ethers.constants.MaxUint256 // deadline
    );
    await addLiqTx.wait();
    return {
      amount,
      feeSlotKey,
    };
  }

  it("add/remove liquidity", async () => {
    const { amount, feeSlotKey } = await addLiquidity();
    expect(await market.totalSupply(feeSlotKey)).to.equal(amount);

    const removeLiqAmount = amount.div(2);

    await (
      await market.connect(tester).setApprovalForAll(usumRouter.address, true)
    ).wait();

    const removeLiqTx = await usumRouter.connect(tester).removeLiquidity(
      oracleProvider.address,
      settlementToken.address,
      feeSlotKey,
      removeLiqAmount,
      0, // amountMin
      tester.address,
      ethers.constants.MaxUint256 // deadline
    );

    await removeLiqTx.wait();

    expect(await market.totalSupply(feeSlotKey)).to.equal(removeLiqAmount);
  });

  describe("position test", async () => {
    let routerContract: USUMRouter;
    before(async () => {
      const liqAmount = ethers.utils.parseEther("500");
      await addLiquidity(liqAmount, 10);
      await addLiquidity(liqAmount, -10);
      const createAccountTx = await accountFactory
        .connect(trader)
        .createAccount();
      await createAccountTx.wait();

      const traderAccount = await usumRouter.connect(trader).getAccount();

      logYellow(`\ttraderAccount: ${traderAccount}`);

      const transferTx = await settlementToken
        .connect(trader)
        .transfer(traderAccount, ethers.utils.parseEther("50"));
      await transferTx.wait();

      routerContract = usumRouter.connect(trader);
      await (
        await settlementToken
          .connect(trader)
          .approve(routerContract.address, ethers.constants.MaxUint256)
      ).wait();
    });
    it("open long position", async () => {
      const takerMargin = ethers.utils.parseEther("1");
      const makerMargin = ethers.utils.parseEther("5");
      const openPositionTx = await routerContract.openPosition(
        oracleProvider.address,
        settlementToken.address,
        1,
        10000,
        takerMargin, // losscut 1 token
        makerMargin, // profit stop 10 token,
        makerMargin.mul(1).div(100), // maxAllowFee (1% * makerMargin)
        ethers.constants.MaxUint256
      );
      const receipt = await openPositionTx.wait();
      console.log(receipt);
      //TODO assert result
    });

    it("open short position ", async () => {
      const takerMargin = ethers.utils.parseEther("1");
      const makerMargin = ethers.utils.parseEther("5");
      const openPositionTx = await routerContract.openPosition(
        oracleProvider.address,
        settlementToken.address,
        -1,
        10000,
        takerMargin, // losscut 1 token
        makerMargin, // profit stop 10 token,
        makerMargin.mul(1).div(100), // maxAllowFee (1% * makerMargin)
        ethers.constants.MaxUint256
      );
      const receipt = await openPositionTx.wait();
      console.log(receipt);
      //TODO assert result
    });
  });

  // execute keeper
});

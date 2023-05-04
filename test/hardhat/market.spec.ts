import {
  OracleProviderMock,
  USUMMarket,
  USUMMarketFactory,
  Token,
  AccountFactory,
  USUMRouter,
  KeeperFeePayerMock,
  USUMLiquidator,
  Account,
} from "../../typechain-types";
import { ethers } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deploy as marketDeploy } from "./deployMarket";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { BigNumber } from "ethers";
import { logYellow } from "./log-utils";

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
let traderAccount: Account;
let traderRouter: USUMRouter;
const eth100 = ethers.utils.parseEther("100");

async function faucet(account: SignerWithAddress) {
  const faucetTx = await settlementToken
    .connect(account)
    .faucet(ethers.utils.parseEther("10000"));
  await faucetTx.wait();
}

const prepareMarketTest = async () => {
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

  await faucet(tester);
  await faucet(trader);

  const createAccountTx = await accountFactory.connect(trader).createAccount();
  await createAccountTx.wait();

  const traderAccountAddr = await usumRouter.connect(trader).getAccount();
  traderAccount = await ethers.getContractAt("Account", traderAccountAddr);

  logYellow(`\ttraderAccount: ${traderAccount}`);

  const transferTx = await settlementToken
    .connect(trader)
    .transfer(traderAccountAddr, ethers.utils.parseEther("500"));
  await transferTx.wait();

  traderRouter = usumRouter.connect(trader);
  await (
    await settlementToken
      .connect(trader)
      .approve(traderRouter.address, ethers.constants.MaxUint256)
  ).wait();
};
describe("market test", async function () {
  // start anvil & deploy contract
  // current oracle view
  // set oracle price -> return oracle version을 포함한 어떤 정보
  // add/remove liquidity
  // open/close position
  // execute keeper

  before(async () => {
    await prepareMarketTest();
  });

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

  describe("position & account test", async () => {
    before(async () => {
      // market deploy
      await prepareMarketTest();

      await addLiquidity(eth100, 1);
      await addLiquidity(eth100.mul(5), 10);
      await addLiquidity(eth100, -1);
      await addLiquidity(eth100.mul(5), -10);
    });

    it("open long position", async () => {
      expect(await traderAccount.getPositionIds(market.address)).to.deep.equal(
        []
      );

      const takerMargin = ethers.utils.parseEther("100");
      const makerMargin = ethers.utils.parseEther("500");
      const openPositionTx = await traderRouter.openPosition(
        oracleProvider.address,
        settlementToken.address,
        1,
        500,
        takerMargin, // losscut 1 token
        makerMargin, // profit stop 10 token,
        makerMargin.mul(1).div(100), // maxAllowFee (1% * makerMargin)
        ethers.constants.MaxUint256
      );
      const receipt = await openPositionTx.wait();
      console.log(receipt);

      const positionIds = await traderAccount.getPositionIds(market.address);
      console.log(positionIds);

      expect(positionIds.length).to.equal(1);
      const position = await market.getPosition(positionIds[0]);

      console.log("position", position);
      console.log("slot0 amount", position._slotMargins[0].amount);
      const slot0 = position._slotMargins.find((p) => p.tradingFeeRate == 1);
      console.log("slot0", slot0);
      expect(slot0?.amount).to.equal(eth100);
      const slot2 = position._slotMargins.find((p) => p.tradingFeeRate === 10);
      expect(slot2?.amount).to.equal(eth100.mul(4));
      const totalSlotMargin = position._slotMargins.reduce(
        (acc, curr) => acc.add(curr.amount),
        BigNumber.from(0)
      );
      expect(makerMargin).to.equal(totalSlotMargin);
    });

    it("open short position ", async () => {
      const takerMargin = ethers.utils.parseEther("100");
      const makerMargin = ethers.utils.parseEther("500");
      const openPositionTx = await traderRouter.openPosition(
        oracleProvider.address,
        settlementToken.address,
        -1,
        500,
        takerMargin, // losscut 1 token
        makerMargin, // profit stop 10 token,
        makerMargin.mul(1).div(100), // maxAllowFee (1% * makerMargin)
        ethers.constants.MaxUint256
      );
      const receipt = await openPositionTx.wait();
      console.log(receipt);
      //TODO assert result

      const positionIds = await traderAccount.getPositionIds(market.address);
      console.log(positionIds);

      expect(positionIds.length).to.equal(2);
      const position = await market.getPosition(positionIds[1]);

      console.log("position", position);
      console.log("slot0 amount", position._slotMargins[0].amount);
      const slot0 = position._slotMargins.find((p) => p.tradingFeeRate === 1);
      console.log("slot0", slot0);
      expect(slot0?.amount).to.equal(eth100);
      const slot2 = position._slotMargins.find((p) => p.tradingFeeRate === 10);
      expect(slot2?.amount).to.equal(eth100.mul(4));
      const totalSlotMargin = position._slotMargins.reduce(
        (acc, curr) => acc.add(curr.amount),
        BigNumber.from(0)
      );
      expect(makerMargin).to.equal(totalSlotMargin);
    });
  });

  describe("liquidation test", async () => {
    before(async()=>{
      await prepareMarketTest();
      await addLiquidity(eth100, 1);
      await addLiquidity(eth100.mul(5), 10);
      await addLiquidity(eth100, -1);
      await addLiquidity(eth100.mul(5), -10);
    })

    it('liquidate long position ', async()=>{
      
      oracleProvider.increaseVersion('1000')
      const takerMargin = ethers.utils.parseEther("100");
      const makerMargin = ethers.utils.parseEther("500");
      const openPositionTx = await traderRouter.openPosition(
        oracleProvider.address,
        settlementToken.address,
        1,
        500,
        takerMargin, // losscut 1 token
        makerMargin, // profit stop 10 token,
        makerMargin.mul(1).div(100), // maxAllowFee (1% * makerMargin)
        ethers.constants.MaxUint256
      );

      // change oracle price
       
      // keeper call

      // check liquidation result 
    })

    it('liquidate short position ', async()=>{
      

    })
  });
  // execute keeper
});

import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { deployContract, hardhatErrorPrettyPrint } from "../../utils";
import { deploy as deployLens } from "./deploy_lens";
import { deploy as deployMarket } from "../../deployMarket";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import {
  AccountFactory,
  USUMLens,
  USUMMarket,
  USUMRouter,
} from "@usum/typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

async function fixture() {
  return await hardhatErrorPrettyPrint(async () => {
    const lens = await deployLens();
    const { market, usumRouter } = await deployMarket();
    return { lens, market, usumRouter };
  });
}

describe("USUM Lens", async function () {
  let lens: USUMLens;
  let market: USUMMarket;
  let usumRouter: USUMRouter;
  let signer: SignerWithAddress;
  let trader: SignerWithAddress;

  before(async () => {
    ({ lens, market, usumRouter } = await loadFixture(fixture));
    [signer, trader] = await ethers.getSigners();
  });
  
  it("addLiquidity", async () => {
    const feeRate = 1;
    const oneEther = ethers.utils.parseEther("1");
    const expectedLiquidity = await lens.estimatedLiquidity(
      market.address,
      feeRate,
      oneEther
    );

    // address market,
    // int16 feeRate,
    // uint256 amount,
    // address recipient,
    // uint256 deadline
    const tx = await usumRouter
      .connect(trader)
      .addLiquidity(
        market.address,
        feeRate,
        oneEther,
        trader.address,
        ethers.constants.MaxUint256
      );

    await tx.wait();
    expect(await market.balanceOf(trader.address, feeRate)).to.equal(
      expectedLiquidity
    );
  });

  it("removeLiquidity", async () => {
    const feeRate = 1;
    const oneEther = ethers.utils.parseEther("1");
    const expectedAmount = await lens.estimatedAmount(
      market.address,
      feeRate,
      oneEther
    );

    // address market,
    // int16 feeRate,
    // uint256 liquidity,
    // uint256 amountMin,
    // address recipient,
    // uint256 deadline
    const tx = await usumRouter
      .connect(trader)
      .removeLiquidity(
        market.address,
        feeRate,
        oneEther,
        1,
        trader.address,
        ethers.constants.MaxUint256
      );

    await tx.wait();
    expect(await market.balanceOf(trader.address, feeRate)).to.equal(
      expectedAmount
    );
  });
});

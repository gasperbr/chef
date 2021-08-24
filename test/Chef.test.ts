import { network, ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

describe("Chef", function () {

  /* 

          |     zzzzz     |
          |     zzzzz     |
  ...xxxxx|xxxxxxxxxx     |
  ...yyyyy|yyyyyyyyyyyyyyy|yyyy...
          |               |

  total reward duration = 15 periods
  LPs can calaim total/15 rewards for one period

  */

  it("Should allocate rewards proportionally", async function () {

    const [alice, bob, carol, dave] = await ethers.getSigners();
    const unit = BigNumber.from(10).pow(18);
    const mine = getMiner(Math.floor(new Date().getTime() / 1000));

    const Chef = await ethers.getContractFactory("Chef3");
    const chef = await Chef.deploy();
    const TokenFactory = await ethers.getContractFactory("Token");
    const lpToken = await TokenFactory.deploy();
    const rewardToken = await TokenFactory.deploy();
    const rewardAmount = unit.mul(3);
    await mine();

    await lpToken.mint(alice.address, unit);
    await lpToken.mint(bob.address, unit);
    await lpToken.mint(carol.address, unit.mul(2));
    await rewardToken.mint(dave.address, rewardAmount);
    await mine();

    // stake alice 
    await chef.connect(alice).stake(lpToken.address, await lpToken.balanceOf(alice.address));
    await mine();

    // stake bob
    await chef.connect(bob).stake(lpToken.address, await lpToken.balanceOf(bob.address));
    let nextBlockTimestamp = await mine();

    // add incentive (for "15 periods")
    const incentive = [0, 0, nextBlockTimestamp + 15 * 10000, 0, rewardAmount, 0, rewardToken.address];
    await chef.connect(dave).addIncentive(lpToken.address, incentive);
    nextBlockTimestamp = await mine();
    const incentiveStartTime = (await chef.incentives(lpToken.address, 0)).startTime;
    const incentiveEndTime = (await chef.incentives(lpToken.address, 0)).endTime;
    console.log(`from: ${incentiveStartTime}, to: ${incentiveEndTime}`);

    // incentives have started - assert pool stale is correct
    const poolState = await chef.poolState(lpToken.address);
    expect(poolState.accLiquiditySeconds).to.be.eq(unit.mul(10000).add(unit.mul(20000)), "Didn't update ls");

    // alice claim rewards for 1 period
    const aliceStakeOld = await chef.stakes(alice.address, lpToken.address);
    let aliceRewardBalanceOld = await rewardToken.balanceOf(alice.address);
    await chef.connect(alice).claimRewards(lpToken.address, [0]);
    await mine();
    const aliceStakeNew = await chef.stakes(alice.address, lpToken.address);
    let aliceRewardNew = (await rewardToken.balanceOf(alice.address));
    let aliceReward = aliceRewardNew.sub(aliceRewardBalanceOld);
    aliceRewardBalanceOld = aliceRewardNew;
    expect(aliceStakeOld.createdAt).to.be.lessThan(aliceStakeNew.createdAt, "didn't reset alice stake time");
    expect(aliceReward).to.be.eq(rewardAmount.div(15).div(2), "din't send alice the reward");

    // alice claim rewards for another period
    await chef.connect(alice).claimRewards(lpToken.address, [0]);
    await mine();
    aliceRewardNew = (await rewardToken.balanceOf(alice.address));
    aliceReward = aliceRewardNew.sub(aliceRewardBalanceOld);
    aliceRewardBalanceOld = aliceRewardNew;
    expect(aliceRewardNew).to.be.eq(rewardAmount.div(15), "didn't send alice the reward");
    expect(aliceReward).to.be.eq(rewardAmount.div(15).div(2), "alice doesn't have the right total reward amount");

    await mine(2);

    await chef.connect(carol).stake(lpToken.address, await lpToken.balanceOf(carol.address));
    await mine(5);
    expect((await chef.stakes(carol.address, lpToken.address)).createdAt).to.be.eq(incentiveStartTime + 50000);

    await chef.connect(carol).claimRewards(lpToken.address, [0]);
    await chef.connect(carol).withdraw(lpToken.address, (await chef.stakes(carol.address, lpToken.address)).liquidity);

    await mine(10);

    await chef.connect(alice).claimRewards(lpToken.address, [0]);
    await mine();
    await chef.connect(bob).claimRewards(lpToken.address, [0]);
    await mine();
    await chef.connect(alice).withdraw(lpToken.address, (await chef.stakes(alice.address, lpToken.address)).liquidity);
    await chef.connect(bob).withdraw(lpToken.address, (await chef.stakes(bob.address, lpToken.address)).liquidity);
    await mine();

    const _alice = await rewardToken.balanceOf(alice.address)
    const _bob = await rewardToken.balanceOf(bob.address)
    const _carol = await rewardToken.balanceOf(carol.address)
    const sum = _alice.add(_bob).add(_carol);
    expect(sum).to.be.eq(rewardAmount);
    expect(_alice.gt(0)).to.be.true;
    expect(_bob.gt(0)).to.be.true;
    expect(_carol.gt(0)).to.be.true;

  });
});

// each mined bock will have a 10k seconds timestamp increment
function getMiner(_currentTime) {
  let currentTime = _currentTime;
  return async (i = 1) => {
    for (let j = 0; j < i; j++) {
      await network.provider.request({ method: "evm_setNextBlockTimestamp", params: [currentTime] });
      await network.provider.request({ method: "evm_mine" });
      currentTime += 10000;
    }
    return currentTime;
  }
}
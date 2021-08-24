/* // SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "hardhat/console.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint256) external;
    function transfer(address, uint256) external;
}

interface IPool is IERC20 {}

contract ChefBad {
    
    struct Incentive {
        uint32 startTime;
        uint32 endTime;
        uint32 lastUpdate;
        uint128 rewardUnclaimed;
        uint128 rawUnclaimed;
        uint256 accRewardPerLiquidity;
        IERC20 token;
    }

    struct Stake {
        uint128 liquidity;
        uint32 createdAt;
    }

    struct Debt {
        uint128 debt;
        uint32 updatedAt;
    }

    mapping(IPool => uint256) public incentiveCount;

    mapping(address => mapping(IPool => Stake)) public stakes;

    mapping(IPool => mapping(uint256 => Incentive)) public incentives;

    mapping(bytes32 => uint256) public debts; // bytes32 := keccak256(user, pool, incentiveId)

    modifier update(IPool pool, uint256 incentiveId) {
        Incentive memory incentive = incentives[pool][incentiveId];
        uint256 currentTime = block.timestamp;
        uint256 passedTime = max(currentTime, incentive.endTime) - incentive.lastUpdate;
        uint256 totalTime = incentive.endTime - min(incentive.endTime, incentive.lastUpdate);
        if (totalTime != 0) {
            uint256 reward = incentive.rewardUnclaimed * passedTime / totalTime;
            incentives[pool][incentiveId].accRewardPerLiquidity += reward << 128 / pool.balanceOf(address(this));
            incentives[pool][incentiveId].rewardUnclaimed -= uint128(reward);
        }
        _;
    }

    function addIncentive(IPool pool, Incentive memory incentive) public {
        require(block.timestamp < incentive.startTime, "");
        require(incentive.startTime < incentive.endTime, "");
        incentive.token.transferFrom(msg.sender, address(this), incentive.rewardUnclaimed);
        incentive.lastUpdate = uint32(block.timestamp);
        incentives[pool][incentiveCount[pool]++] = incentive;
    }

    function stake(IPool pool, uint256 amount, uint256[] memory incentiveIds) public {
        pool.transferFrom(msg.sender, address(this), amount);
        stakes[msg.sender][pool].createdAt = uint32(block.timestamp);
        uint256 newLiquidity = stakes[msg.sender][pool].liquidity = uint128(amount);
        for (uint256 i = 0; i < incentiveIds.length; i++) {
            uint256 id = incentiveIds[i];
            increaseRewardDebt(pool, id, incentives[pool][id].accRewardPerLiquidity * newLiquidity);
        }
        stakes[msg.sender][pool].liquidity = uint128(newLiquidity);
    }

    function claimRewards(IPool pool, uint256 incentiveId) public update(pool, incentiveId) {
        uint256 rewards = getRewards(pool, incentiveId);
        increaseRewardDebt(pool, incentiveId, rewards);
        incentives[pool][incentiveId].token.transfer(msg.sender, rewards);
    }

    function getRewards(IPool pool, uint256 incentiveId) public view returns (uint256 rewards) {
        Incentive memory incentive = incentives[pool][incentiveId];
        Stake memory usersStake = stakes[msg.sender][pool];
        uint256 rewardDebt = getRewardDebt(pool, incentiveId);
        if (usersStake.createdAt < incentive.startTime) { // :(
            rewards = usersStake.liquidity * incentive.accRewardPerLiquidity - rewardDebt;
        }
    }

    function withdraw(IPool pool, uint256 amount) public {
    }

    function getRewardDebt(IPool pool, uint256 incentiveId) internal view returns (uint256) {
        return debts[keccak256(abi.encodePacked(msg.sender, pool, incentiveId))];
    }

    function increaseRewardDebt(IPool pool, uint256 incentiveId, uint256 debt) internal {
        debts[keccak256(abi.encodePacked(msg.sender, pool, incentiveId))] += debt;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }
}
 */
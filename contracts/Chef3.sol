// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "hardhat/console.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint256) external;
    function transfer(address, uint256) external;
}

interface IPool is IERC20 {}

contract Chef3 {
    
    // liquidity * seconds
    // we spread our rewards over some surface area
    struct Incentive {
        uint32 startTime;
        uint32 endTime;
        uint128 totalRewards;
        uint224 liquiditySecondsStart;
        uint224 liquiditySecondsFinal;
        IERC20 token;
    }

    struct PoolState {
        uint224 liquiditySeconds;
        uint32 lastUpdate;
    }

    struct Stake {
        uint128 liquidity;
        uint32 createdAt;
    }

    mapping(IPool => PoolState) public poolState;

    mapping(address => mapping(IPool => Stake)) public stakes;
    
    mapping(IPool => uint256) public incentiveCount;

    mapping(IPool => mapping(uint256 => Incentive)) public incentives;

    modifier updatePoolState(IPool pool) {
        if (poolState[pool].lastUpdate != uint32(block.timestamp)) {
            poolState[pool].liquiditySeconds += 
                uint224((block.timestamp - uint256(poolState[pool].lastUpdate)) * pool.balanceOf(address(this)));
            poolState[pool].lastUpdate = uint32(block.timestamp);
        }
        _;
    }

    function addIncentive(IPool pool, Incentive memory incentive) public updatePoolState(pool) {
        incentive.startTime = uint32(block.timestamp);
        require(incentive.startTime < incentive.endTime, "");
        require(incentive.liquiditySecondsFinal == 0, "This is set automatically at the end");
        incentive.token.transferFrom(msg.sender, address(this), incentive.totalRewards);
        incentive.liquiditySecondsStart = poolState[pool].liquiditySeconds;
        incentives[pool][incentiveCount[pool]++] = incentive;
    }

    function stake(IPool pool, uint256 amount) public updatePoolState(pool) {
        pool.transferFrom(msg.sender, address(this), amount);
        stakes[msg.sender][pool].createdAt = uint32(block.timestamp);
        stakes[msg.sender][pool].liquidity += uint128(amount);
    }

    function claimRewards(IPool pool, uint256[] memory incentiveIds) public updatePoolState(pool) {
        Stake storage userStake = stakes[msg.sender][pool];
        for (uint256 i = 0; i < incentiveIds.length; i++) {
            Incentive storage incentive = incentives[pool][incentiveIds[i]];
            if (i > 0) {
                require(incentiveIds[i - 1] < incentiveIds[i], "Double spend");
            }
            (bool end, uint224 lastLiquiditySeconds) = _endIncentive(pool, incentiveIds[i]);
            if (end) {
                incentive.liquiditySecondsFinal = lastLiquiditySeconds;
                incentive.endTime = uint32(block.timestamp);
            }
            uint256 totalLiquiditySeconds = lastLiquiditySeconds - incentive.liquiditySecondsStart;
            uint256 duration = incentive.endTime - incentive.startTime;
            uint256 passed = min(block.timestamp, incentive.endTime) - incentive.startTime;
            uint256 userStartTime = max(userStake.createdAt, incentive.startTime);
            uint256 userEndTime = min(block.timestamp, incentive.endTime);
            uint256 userLiquiditySeconds = userStake.liquidity * (userEndTime - userStartTime);
            uint256 reward = (incentive.totalRewards * passed / duration) * userLiquiditySeconds / totalLiquiditySeconds;
            
            incentive.token.transfer(msg.sender, reward);
        }
        userStake.createdAt = uint32(block.timestamp);
    }

    function _endIncentive(IPool pool, uint256 incentiveId) internal view returns (bool, uint224) {
        Incentive memory incentive = incentives[pool][incentiveId];
        if (incentive.endTime < block.timestamp) {
            if (incentive.liquiditySecondsFinal != 0) {
                return (true, poolState[pool].liquiditySeconds);
            }
            return (false, incentive.liquiditySecondsFinal);
        }
        return (false, poolState[pool].liquiditySeconds);
    }

    function withdraw(IPool pool, uint256 amount) public updatePoolState(pool) {
        pool.transfer(msg.sender, amount);
        stakes[msg.sender][pool].createdAt = uint32(block.timestamp);
        stakes[msg.sender][pool].liquidity -= uint128(amount);
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }
}

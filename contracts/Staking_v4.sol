// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Token.sol";

/**  
 * @dev  TokenA : BNB,ETH,USDT,...
 *       TokenB : IVIRSECoin 
 *
 * @dev  Staking is for user who want to get tokenB by lock their tokenA
 *       in this StakingBonus contract and receive tokenB after
 *       an amount of time 
 *
 * @dev  Maximum tokenA each user can stake in one period staking is 50000 token
 * @dev  Minimum tokenA each user can stake in one period staking is 1000 token
 *
 * @dev  In this contract, for testing, there are 4 duration staking is 30,60,90,120
 *       seconds and bonus rate between tokenA and tokenB described below :
 *       +) 30 seconds - 3,4%
 *       +) 60 seconds - 4%   
 *       +) 90 seconds - 4%       
 *       +) 120 seconds - 5,6%   
 * Example : If user stake 5000 tokenA in 120 second , after withdrawFulltime, they 
 * will get 5000 takenA back and 5000*5,6% = 280 tokenB bonus
 *
 * @dev  When there isn't enough token to pay reward, the pool will stop accepting 
 *       user to stake
 *
 * @dev  In reality, different tokenB should have diffirent bonus rate with tokenA
 *
 * 
*/

contract StakingBonus{
    Token public immutable tokenA;
    Token public immutable tokenB;
    address public owner;
    uint public d3 = 30;    // r3 = 3.4%
    uint public d6 = 60;    // r6 = 4%
    uint public d9 = 90;    // r9 = 4%
    uint public d12 = 120;  // r12 = 5.6%
    uint public maximumTokenStaking = 50000;
    uint public minimumTokenStaking = 1000;
    uint public bonusWillPay = 0;
    /**
     * @dev User address => staked amount of user
    */ 
    mapping(address => uint) private balanceStakeOf;
    /**
     * @dev User address => time end stake of user
    */ 
    mapping(address => uint) private timeEndStake;
     /**
     * @dev User address => duration stake
    */ 
    mapping(address => uint) private durationUser;
    

    constructor(address _tokenA,address _tokenB) {
        owner = msg.sender;
        tokenA = Token(_tokenA);
        tokenB = Token(_tokenB);
    }
    /**
     * @dev set stake of user = 0, time end stake of user = 0 and duration
     *      staking of user = 0
    */ 
    modifier resetStakeOfUser(){
        _;
        uint bonus = calculateBonus(balanceStakeOf[msg.sender],durationUser[msg.sender]);
        bonusWillPay -= bonus;
        balanceStakeOf[msg.sender] = 0;
        timeEndStake[msg.sender] = 0;
        durationUser[msg.sender] = 0;
    }

    /**
     * @dev Require function must in staking state
    */ 
    modifier requireStaking(){
        require(timeEndStake[msg.sender] > 0, "didn't stake");
        _;
    }

    /**
     * @dev Require of stake funtion
    */ 
    modifier requireStartStaking(uint _amount,uint _duration){
        require(_duration == d3 || _duration == d6 || _duration == d9 || _duration == d12, "wrong duration");
        require(timeEndStake[msg.sender] == 0, "already in stake");
        require(_amount > 0, "amount = 0");
        require(_amount <= maximumTokenStaking, "maximum amount staking should less than or equal to 50000 token");
        require(_amount >= minimumTokenStaking, "minimum amount staking should more than or equal to 1000 token");
        bonusWillPay += calculateBonus( _amount,_duration);
        require(tokenB.balanceOf(address(this)) >= bonusWillPay,"not enough balance to pay reward");
        _;
    }

    /**
     * @dev Stake
    */ 
    function stake(uint _amount,uint _duration) requireStartStaking(_amount,_duration) external{ 
        tokenA.transferFrom(msg.sender, address(this), _amount);
        balanceStakeOf[msg.sender] += _amount;
        timeEndStake[msg.sender] = block.timestamp + _duration;
        durationUser[msg.sender] = _duration; 
    }

    /**
     * @dev Withdraw when duration of staking is over
     * @dev Get staking tokenA and bonus tokenB   
    */ 
    function withdrawFulltime() external requireStaking resetStakeOfUser{
        require(timeEndStake[msg.sender] < block.timestamp ,"haven't time yet");
        uint bonus = calculateBonus(balanceStakeOf[msg.sender],durationUser[msg.sender]);
        require(tokenB.balanceOf(address(this)) >= bonus,"not enough balance");
            if(bonus > 0) {
                tokenA.transfer(msg.sender, balanceStakeOf[msg.sender]);
                tokenB.transfer(msg.sender, bonus);
            }  
    }

    /**s
     * @dev Calculate bonus 
    */ 
    function calculateBonus(uint _amount,uint _duration) public view returns(uint bonus){
        require(_duration == d3 || _duration == d6 || _duration == d9 || _duration == d12);
        if(_duration == d3){
            bonus = _amount*34/1000; // r3 = 3.4%;
        }
        else if(_duration == d6){
            bonus = _amount*40/1000; // r6 = 4%;
        }
        else if(_duration == d9){
            bonus = _amount*40/1000; // r9 = 4%;
        }
        else if(_duration == d12){
            bonus = _amount*56/1000; // r12 = 5,6%;
        }
        return bonus;
    }

    /**
     * @dev Get time left to earn reward of `_account`
    */ 
    function viewTimeUntilWithDrawFullTime(address _account) view external returns(uint){ 
        return timeEndStake[_account] - block.timestamp;
    }
 
    /**
     * @dev User force withdraw when the time had not yet come
     * @dev When force withdraw, user don't get any bonus, just get staking token 
    */ 
    function forceWithdraw() external requireStaking resetStakeOfUser{
        require(timeEndStake[msg.sender] > block.timestamp ,"go to withdrawFullTime");
        tokenA.transfer(msg.sender, balanceStakeOf[msg.sender]);
    }

    /**
     * @dev Get time end stake of `_account`
    */ 
    function getTimeEndStake(address _account) external view returns(uint){
        return timeEndStake[_account];
    }

    /**
     * @dev Get balance stake of `_account`
    */ 
    function getBalanceStakeOf(address _account) external view returns(uint){
        return balanceStakeOf[_account];
    }
}

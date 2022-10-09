// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "./Token.sol";

/**  
 * @dev  TokenA : BNB,ETH,USDT,...
 *       TokenB : IVIRSECoin 
 *
 * @dev  Staking is for user who want to get tokenB by lock their tokenA
 *       in this StakingBonus contract and receive tokenB after
 *       an amount of time a
 *
 *
 * @dev  In this contract, for testing, there are 4 duration staking is 30,60,90,120
 *       seconds and bonus rate between tokenA and tokenB described below :
 *       +) 30 seconds - 3%
 *       +) 60 seconds - 6%   
 *       +) 90 seconds - 9%       
 *       +) 120 seconds - 12%   
 * Example : If user stake 5000 tokenA in 120 second , after withdrawFulltime, they 
 * will get 5000 takenA back and 5000*12% = 600 tokenB bonus
 * 
 * @dev  User choose forceWithdraw , they will get 1% bonus rate for each 10 second ( not stack )
 * Example : If user stake 5000 tokenA in 90 second , they choose forceWithdraw after 
 *       +) 40 second : they will get 4% rate equal to 5000*4% = 200 tokenB
 *       +) 17 second : they will get 1% rate equal to 5000*1% = 50 tokenB  
 *       +) 85 second : they will get 8% rate equal to 5000*8% = 400 tokenB  
 *         
 * @dev  When there isn't enough token to pay reward, the pool will stop accepting 
 *       user to stake
 *
 * @dev  In reality, different tokenB should have diffirent bonus rate with tokenA
*/

contract StakingBonus{
    using Counters for Counters.Counter;
    Counters.Counter public ID;
    Token public immutable tokenA;
    Token public immutable tokenB;
    address public owner;
    uint public d3 = 30;    // r3 = 3%
    uint public d6 = 60;    // r6 = 6%
    uint public d9 = 90;    // r9 = 9%
    uint public d12 = 120;  // r12 = 12%
    uint public bonusWillPay = 0;

    struct StakingUserInfo{
        uint balanceStakeOf;
        uint timeEndStake;
        uint timeStartStake;
        uint durationUser;
        uint IDStake;
    }    
    
    mapping(address => StakingUserInfo[]) private stakingUserInfo; 

    constructor(address _tokenA,address _tokenB) {
        owner = msg.sender;
        tokenA = Token(_tokenA);
        tokenB = Token(_tokenB);
    }

    // modifier ------------------------------------------------------------------------------------------------------

    /**
     * @dev set stake of user = 0, time end stake of user = 0 and duration
     *      staking of user = 0
    */ 
    modifier resetStakeOfUser(uint _ID){
        _;
        uint bonus = calculateBonus(findStake(msg.sender,_ID).balanceStakeOf,findStake(msg.sender,_ID).durationUser);
        bonusWillPay -= bonus;
        bool check = false;
        uint stakeLength = stakingUserInfo[msg.sender].length;
        for(uint i=0;i< stakeLength; i++){
            if(_ID == stakingUserInfo[msg.sender][i].IDStake){
                stakingUserInfo[msg.sender][i] = stakingUserInfo[msg.sender][stakeLength - 1];
                check = true;
            }
        }
        if(check){
            stakingUserInfo[msg.sender].pop();
        }
    }

    /**
     * @dev Require function must in staking state
    */ 
    modifier requireStaking(uint _ID){
        require(findStake(msg.sender,_ID).timeEndStake > 0, "didn't stake");
        _;
    }

    /**
     * @dev Require of stake funtion
    */ 
    modifier requireStartStaking(uint _amount,uint _duration){
        require(_duration == d3 || _duration == d6 || _duration == d9 || _duration == d12, "wrong duration");
        require(_amount > 0, "amount = 0");
        bonusWillPay += calculateBonus( _amount,_duration);
        require(tokenB.balanceOf(address(this)) >= bonusWillPay,"not enough balance to pay reward");
        _;
    }

    // function -----------------------------------------------------------------------------------------

    function totalStakingBalanceOfUser(address _account) view public returns(uint){
        uint total;
        for(uint i = 0;i < stakingUserInfo[_account].length; i++){
            total += stakingUserInfo[_account][i].balanceStakeOf;
        }
        return total;
    }

    function findStake(address _account, uint _ID) view internal returns(StakingUserInfo memory){
        for(uint i=0;i< stakingUserInfo[_account].length; i++){
            if(_ID == stakingUserInfo[_account][i].IDStake){
                return stakingUserInfo[_account][i];
            }
        }
        revert('Not found');
    }

    function addStakeOfUser(uint _balanceStakeOf, uint _timeEndStake, uint _timeStartStake, uint _durationUser,address _account) internal{
        StakingUserInfo memory newStake = StakingUserInfo(_balanceStakeOf,_timeEndStake,_timeStartStake,_durationUser,ID.current());
        stakingUserInfo[_account].push(newStake);
        ID.increment();
    }

    /**
     * @dev Stake
    */ 
    function stake(uint _amount,uint _duration) requireStartStaking(_amount,_duration) external{ 
        uint _timeEndStake = block.timestamp + _duration;
        uint _timeStartStake = block.timestamp;
        addStakeOfUser(_amount, _timeEndStake,_timeStartStake, _duration, msg.sender);
        tokenA.transferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @dev Withdraw when duration of staking is over
     * @dev Get staking tokenA and bonus tokenB   
    */ 
    function withdrawFulltime(uint _ID) external requireStaking(_ID) resetStakeOfUser(_ID){
        require(findStake(msg.sender,_ID).timeEndStake < block.timestamp ,"haven't time yet");
        uint bonus = calculateBonus(findStake(msg.sender,_ID).balanceStakeOf,findStake(msg.sender,_ID).durationUser);
        require(tokenB.balanceOf(address(this)) >= bonus,"not enough balance");
            if(bonus > 0) {
                tokenA.transfer(msg.sender, findStake(msg.sender,_ID).balanceStakeOf);
                tokenB.transfer(msg.sender, bonus);
            }  
    }
 
    /**
     * @dev User force withdraw when the time had not yet come
     * @dev When force withdraw, user get 1% bonus per every 10 second
    */ 
    function forceWithdraw(uint _ID) external requireStaking(_ID) resetStakeOfUser(_ID){
        require(findStake(msg.sender,_ID).timeEndStake > block.timestamp ,"go to withdrawFullTime");
        uint bonus = calculateForceWithdrawBonus(findStake(msg.sender,_ID).balanceStakeOf,findStake(msg.sender,_ID).timeStartStake);
        require(tokenB.balanceOf(address(this)) >= bonus,"not enough balance");
        if(bonus > 0) {
            tokenA.transfer(msg.sender, findStake(msg.sender,_ID).balanceStakeOf);
            tokenB.transfer(msg.sender, bonus);
        }  
    }

    // view function -------------------------------------------------------------------------------------

    /**
     * @dev Calculate forceWithdraw bonus
    */ 
    function calculateForceWithdrawBonus(uint _amount,uint _timeStartStake) public view returns(uint bonus){
        // describe how many `10 second` passed
        uint cycleBonus = (block.timestamp - _timeStartStake) / 10;
        // every 10 second equal 1% rate bonus
        bonus = cycleBonus*_amount*1/100;
        return bonus;
    }

    /**
     * @dev Calculate bonus full time
    */ 
    function calculateBonus(uint _amount,uint _duration) public view returns(uint bonus){
        require(_duration == d3 || _duration == d6 || _duration == d9 || _duration == d12);
        if(_duration == d3){
            bonus = _amount*3/100; // r3 = 3%;
        }
        else if(_duration == d6){
            bonus = _amount*6/100; // r6 = 6%;
        }
        else if(_duration == d9){
            bonus = _amount*9/100; // r9 = 9%;
        }
        else if(_duration == d12){
            bonus = _amount*12/100; // r12 = 12%;
        }
        return bonus;
    }
    
    /**
     * @dev Get skake info of `_account`
    */ 
    function getAllStakeUser(address _account) view external returns(StakingUserInfo[] memory){ 
        return stakingUserInfo[_account];
    }

    /**
     * @dev Get time left to earn reward of `_account`
    */ 
    function viewTimeUntilWithDrawFullTime(address _account,uint _ID) view external returns(uint){ 
        return findStake(_account,_ID).timeEndStake - block.timestamp;
    }

    /**
     * @dev Get time end stake of `_account`
    */ 
    function getTimeEndStake(address _account,uint _ID) external view returns(uint){
        return findStake(_account,_ID).timeEndStake;
    }

    /**
     * @dev Get balance stake of `_account`
    */ 
    function getBalanceStakeOf(address _account,uint _ID) external view returns(uint){
        return findStake(_account,_ID).balanceStakeOf;
    }
}

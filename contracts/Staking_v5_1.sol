// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "./Token.sol";

/**  
 * @dev update in ForceWithdraw , when user stake more than 50% duration stake ( but 
 * not 100%) they can get 20% bonus reward instead of nothing
 * 
*/

contract StakingBonus{
    using Counters for Counters.Counter;
    Counters.Counter public ID;
    Token public immutable tokenA;
    Token public immutable tokenB;
    address public owner;
    uint public d3 = 30;    // r3 = 3.4%
    uint public d6 = 60;    // r6 = 4%
    uint public d9 = 90;    // r9 = 4%
    uint public d12 = 120;  // r12 = 5.6%
    uint public bonusWillPay = 0;

    struct StakingUserInfo{
        uint balanceStakeOf;
        uint timeEndStake;
        uint timeEnd50Stake;
        uint durationUser;
        uint IDStake;
    }    
    
    mapping(address => StakingUserInfo[]) private stakingUserInfo; 

    constructor(address _tokenA,address _tokenB) {
        owner = msg.sender;
        tokenA = Token(_tokenA);
        tokenB = Token(_tokenB);
    }
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

    // mapping (address => mapping (uint => StakingUserInfo)) private findStake;

    function addStakeOfUser(uint _balanceStakeOf,uint _timeEndStake,uint _timeEnd50Stake,uint _durationUser,address _account) internal{
        StakingUserInfo memory newStake = StakingUserInfo(_balanceStakeOf,_timeEndStake,_timeEnd50Stake,_durationUser,ID.current());
        stakingUserInfo[_account].push(newStake);
        ID.increment();
    }

    /**
     * @dev Stake
    */ 
    function stake(uint _amount,uint _duration) requireStartStaking(_amount,_duration) external{ 
        uint _timeEndStake = block.timestamp + _duration;
        uint _timeEnd50Stake = block.timestamp + _duration/2;
        addStakeOfUser(_amount, _timeEndStake, _timeEnd50Stake, _duration, msg.sender);
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
     * @dev User force withdraw when the time had not yet come
     * @dev When force withdraw, user don't get any bonus, just get staking token 
    */ 
    function forceWithdraw(uint _ID) external requireStaking(_ID) resetStakeOfUser(_ID){
        require(findStake(msg.sender,_ID).timeEndStake > block.timestamp ,"go to withdrawFullTime");
        if(findStake(msg.sender,_ID).timeEnd50Stake < block.timestamp){
            uint bonus = calculateBonus(findStake(msg.sender,_ID).balanceStakeOf,findStake(msg.sender,_ID).durationUser)/5; // 20% reward bonus
            require(tokenB.balanceOf(address(this)) >= bonus,"not enough balance");
            if(bonus > 0) {
                tokenA.transfer(msg.sender, findStake(msg.sender,_ID).balanceStakeOf);
                tokenB.transfer(msg.sender, bonus);
            }  
        }else{
            tokenA.transfer(msg.sender, findStake(msg.sender,_ID).balanceStakeOf);
        }
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

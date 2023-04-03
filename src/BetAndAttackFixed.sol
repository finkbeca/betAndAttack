pragma solidity >= 0.8.0 < 0.9.0;

import "./BetAndAttack.sol";
/**
 * @title BetAndAttackFixed
 * @dev A contract inherited from BetAndAttack for testing purposes
 */

 contract BetAndAttackFixed is BetAndAttack {

    constructor(uint256 duration, uint256 _bidMinimum, uint256 _responseTimeThreshold) public payable BetAndAttack(duration, _bidMinimum, _responseTimeThreshold) {
        //Simulated output from DDOS Query
        responseTime = 150;
    }

 }
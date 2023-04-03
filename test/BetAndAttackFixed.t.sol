// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.0 < 0.9.0;

import "forge-std/Test.sol";

import "../src/BetAndAttackFixed.sol";

contract BetAndAttackFixedTest is Test {

    BetAndAttackFixed public BetAndAttack;
    address payable sponsor = payable(address(0x1234));
    address payable attackerOne = payable(address(0x3333));
    address payable attackerTwo = payable(address(0x4444));
    
    uint256 duration1 = 300;
    uint256 bidMinimum1= 20000000;
    uint256 responseTimeThreshold1 = 125;
    uint256 responseTimeThreshold2 = 200;

    function setUp() public {
        vm.deal(sponsor, 2 ether);
        vm.deal(attackerOne, 1 ether);
        vm.deal(attackerTwo, .5 ether);
        
    }

    function initContract_ResponseTimeGreaterThanThreshold() public {
        vm.warp(0);
        vm.startPrank(sponsor);
        BetAndAttack = new BetAndAttackFixed{value: 1 ether}(duration1, bidMinimum1, responseTimeThreshold1);
        vm.stopPrank();
    }

    function initContract_ResponseTimeLessThanThreshold() public {
        vm.warp(0);
        vm.startPrank(sponsor);
        BetAndAttack = new BetAndAttackFixed{value: 1 ether}(duration1, bidMinimum1, responseTimeThreshold2);
        vm.stopPrank();
    }

    function test_InitialState() public {
         // ResponseTime > ResponeTimeThreshold
        initContract_ResponseTimeGreaterThanThreshold();
        uint256 expected = 1 ether;
        assertEq(address(BetAndAttack).balance, expected);
        assertEq(BetAndAttack.reward(), expected);
        assertEq(BetAndAttack.sponsor(), address(sponsor));
        assertEq(BetAndAttack.sponsorWithdrew(), false);
        assertEq(BetAndAttack.bidMinimum(), 20000000 wei );
        assertEq(BetAndAttack.totalBids(), 0);
        assertEq(BetAndAttack.responseTimeThreshold(), 125);
    }

    function test_TimeStamp() public {
         // ResponseTime > ResponeTimeThreshold
        initContract_ResponseTimeGreaterThanThreshold();
        vm.warp(25);
        assertEq(BetAndAttack.getTime(), 25);
    }

    function test_Bid() public {
         // ResponseTime > ResponeTimeThreshold
        initContract_ResponseTimeGreaterThanThreshold();

        // AttackerOneBid
        vm.startPrank(address(attackerOne));
        uint256 bid = .25 ether;
        BetAndAttack.bid{value: bid}();
        vm.stopPrank();


        assertEq(BetAndAttack.totalBids(), bid);
        assertEq(BetAndAttack.balances(address(attackerOne)), bid);

    }

    function test_MultipleBids() public {
         // ResponseTime > ResponeTimeThreshold
        initContract_ResponseTimeGreaterThanThreshold();

        //AttackerOne Bid
        vm.startPrank(address(attackerOne));
        uint256 bid1 = .25 ether;
        BetAndAttack.bid{value: bid1}();
        vm.stopPrank();


        assertEq(BetAndAttack.totalBids(), bid1);
        assertEq(BetAndAttack.balances(address(attackerOne)), bid1);

        // AttackerTwo Bid
        vm.startPrank(address(attackerTwo));
        uint256 bid2 = .5 ether;
        BetAndAttack.bid{value: bid2}();
        vm.stopPrank();


        assertEq(BetAndAttack.totalBids(), bid1 + bid2);
        assertEq(BetAndAttack.balances(address(attackerTwo)), bid2); 

        // AttackerOne Bid (again)
        vm.startPrank(address(attackerOne));
        uint256 bid3 = .25 ether;
        BetAndAttack.bid{value: bid3}();
        vm.stopPrank();


        assertEq(BetAndAttack.totalBids(), bid1 + bid2 + bid3);
        assertEq(BetAndAttack.balances(address(attackerOne)), bid1 + bid3);  

    }

    function testFail_Bid_TimeOver() public {
         // ResponseTime > ResponeTimeThreshold
        initContract_ResponseTimeGreaterThanThreshold();

        //Attacker Bid (Time Over)
        vm.warp(300);
        vm.startPrank(address(attackerOne));
        uint256 bid = .25 ether;
        BetAndAttack.bid{value: bid}();
        vm.stopPrank();
        
    }

    function testFail_Bid_Sponsor() public {
         // ResponseTime > ResponeTimeThreshold
        initContract_ResponseTimeGreaterThanThreshold();

        // Attacker Bid (By Sponsor)
        vm.startPrank(address(sponsor));
        uint256 bid = .25 ether;
        BetAndAttack.bid{value: bid}();
        vm.stopPrank(); 
    }

    function testFail_Bid_invalidBid() public {
         // ResponseTime > ResponeTimeThreshold
       initContract_ResponseTimeGreaterThanThreshold();
        vm.startPrank(address(attackerOne));
        uint256 bid = 20000 wei;
        BetAndAttack.bid{value: bid}();
        vm.stopPrank();
        assertEq(BetAndAttack.totalBids(), bid); 
    }
   

    function test_attackWithdraw_Single_FullReward() public {
        initContract_ResponseTimeGreaterThanThreshold();
        
        // AttackerOne Bid
         vm.startPrank(address(attackerOne));
        uint256 bid1 = .25 ether;
        BetAndAttack.bid{value: bid1}();
        vm.stopPrank();

        uint256 prevBalance = address(attackerOne).balance;
        console.log(prevBalance);

        // Attacker Withdrawl 
        vm.startPrank(address(attackerTwo));
        uint256 bid2 = .25 ether;
        BetAndAttack.bid{value: bid1}();
        vm.stopPrank();

        
        //time to withdrawl period duration1 + 540 where 540 = 300 bidEndTime + 240 withdrawlPeriodStart as set in our contract 
        // @dev time must be greater than 540 + duration
        vm.warp(541+duration1);
        vm.startPrank(address(attackerOne));
        BetAndAttack.attacker_withdraw();
        vm.stopPrank(); 

        assertEq(BetAndAttack.balances(address(attackerOne)), 0);
        assertEq(BetAndAttack.balances(address(attackerTwo)), .5 ether - .25 ether);
        
        // Reward = 1 eth
        // AttackerOne .25 eth
        // AttackerTwo .25 eth

        // ResponseTime = 150ms
        // ResponseTimeThreshold = 125ms

        //Outcome Percentage = 100
        // AttackerOne Reward = (.5 + 1 eth) * (.25/.5) = .75 eth
        assertEq(address(attackerOne).balance, prevBalance + .75 ether);
    }

    function test_attackWithdraw_Single_AttemptDoubleWithdrawl() public {
        initContract_ResponseTimeGreaterThanThreshold();
        
        // AttackerOne Bid
         vm.startPrank(address(attackerOne));
        uint256 bid1 = .25 ether;
        BetAndAttack.bid{value: bid1}();
        vm.stopPrank();

        uint256 prevBalance = address(attackerOne).balance;
        console.log(prevBalance);

        // Attacker Withdrawl 
        vm.startPrank(address(attackerTwo));
        uint256 bid2 = .25 ether;
        BetAndAttack.bid{value: bid1}();
        vm.stopPrank();

        
        //time to withdrawl period duration1 + 540 where 540 = 300 bidEndTime + 240 withdrawlPeriodStart as set in our contract 
        // @dev time must be greater than 540 + duration
        vm.warp(541+duration1);
        vm.startPrank(address(attackerOne));
        BetAndAttack.attacker_withdraw();
        vm.stopPrank(); 

        assertEq(BetAndAttack.balances(address(attackerOne)), 0);
        assertEq(BetAndAttack.balances(address(attackerTwo)), .5 ether - .25 ether);
        
        // Reward = 1 eth
        // AttackerOne .25 eth
        // AttackerTwo .25 eth

        // ResponseTime = 150ms
        // ResponseTimeThreshold = 125ms

        //Outcome Percentage = 100
        // AttackerOne Reward = (.5 + 1 eth) * (.25/.5) = .75 eth
        assertEq(address(attackerOne).balance, prevBalance + .75 ether);

        vm.warp(545+duration1);
        vm.startPrank(address(attackerOne));
        BetAndAttack.attacker_withdraw();
        vm.stopPrank(); 

        assertEq(address(attackerOne).balance, prevBalance + .75 ether);

    }

    function testFail_attackWithdraw_Sponsor() public {
         // ResponseTime > ResponeTimeThreshold
        initContract_ResponseTimeGreaterThanThreshold();

        // SponsorWithdrawl (sponsor)
        vm.startPrank(address(sponsor));
        BetAndAttack.attacker_withdraw();
        vm.stopPrank(); 
    }

    function testFail_attackWithdraw_BeforeTime() public {
         // ResponseTime > ResponeTimeThreshold
        initContract_ResponseTimeGreaterThanThreshold();

         // SponsorWithdrawl (TimeStamp < withdrawlPeriodStart)
        vm.warp(540+duration1);
        vm.startPrank(address(attackerOne));
        BetAndAttack.attacker_withdraw();
        vm.stopPrank(); 
    }



    function test_attackWithdraw_Both_FullReward() public {
         // ResponseTime > ResponeTimeThreshold
        initContract_ResponseTimeGreaterThanThreshold();
        
        // AttackerOne Bid
         vm.startPrank(address(attackerOne));
        uint256 bid1 = .25 ether;
        BetAndAttack.bid{value: bid1}();
        vm.stopPrank();

        // Balance of AttackerOne after Bid
        uint256 prevBalanceAttackerOne = address(attackerOne).balance;
        
        // AttackerTwoBid
        vm.startPrank(address(attackerTwo));
        uint256 bid2 = .25 ether;
        BetAndAttack.bid{value: bid2}();
        vm.stopPrank();

        // Balance of AttackerTwo after Bid
        uint256 prevBalanceAttackerTwo = address(attackerTwo).balance; 
        //time to withdrawl period duration1 + 540 where 540 = 300 bidEndTime + 240 withdrawlPeriodStart as set in our contract 
        // @dev time must be greater than 540 + duration
        vm.warp(541+duration1);
        vm.startPrank(address(attackerOne));
        BetAndAttack.attacker_withdraw();
        vm.stopPrank(); 

        assertEq(BetAndAttack.balances(address(attackerOne)), 0);
        assertEq(BetAndAttack.balances(address(attackerTwo)), .5 ether - .25 ether);
        // Reward = 1 eth
        // AttackerOne .25 eth
        // AttackerTwo .25 eth

        // ResponseTime = 150ms
        // ResponseTimeThreshold = 125ms

        //Outcome Percentage = 100
        // AttackerOne Reward = (.5 + 1 eth) * (.25/.5) = .75 eth
        assertEq(address(attackerOne).balance, prevBalanceAttackerOne + .75 ether);
        assertEq(address(attackerTwo).balance, .25 ether);
        
        // Attacker Withdrawl (AttackerTwo)
        vm.warp(545+duration1);
        vm.startPrank(address(attackerTwo));
        BetAndAttack.attacker_withdraw();
        vm.stopPrank(); 

        assertEq(BetAndAttack.balances(address(attackerOne)), 0);
        assertEq(BetAndAttack.balances(address(attackerTwo)), 0); 

        assertEq(address(attackerOne).balance, prevBalanceAttackerOne + .75 ether);
        assertEq(address(attackerTwo).balance, prevBalanceAttackerTwo + .75 ether); 
    }
    
    function testFail_sponsorWithdrawl_NotSponsor() public {
        // ResponseTime > ResponeTimeThreshold
       initContract_ResponseTimeGreaterThanThreshold();
        
        // AtackerOne Bid
        vm.startPrank(address(attackerOne));
        uint256 bid1 = .25 ether;
        BetAndAttack.bid{value: bid1}();
        vm.stopPrank(); 

        // Sponsor Withdrawl (AttackerOne)
        vm.warp(541+duration1);
        vm.startPrank(address(attackerOne));
        BetAndAttack.sponsor_Withdrawl();
        vm.stopPrank(); 
    }

    function testFail_sponsorWithdrawl_BeforeTime() public {
         // ResponseTime > ResponeTimeThreshold
       initContract_ResponseTimeGreaterThanThreshold();
        // AttackerOne Bid
        vm.startPrank(address(attackerOne));
        uint256 bid1 = .25 ether;
        BetAndAttack.bid{value: bid1}();
        vm.stopPrank(); 

        // Sponsor Withdrawl (One Timestep too early)
        vm.warp(540+duration1);
        vm.startPrank(address(sponsor));
        BetAndAttack.sponsor_Withdrawl();
        vm.stopPrank(); 
    }

    function test_sponsorWithdrawl_NoReward() public {
       // ResponseTime > ResponeTimeThreshold
       initContract_ResponseTimeGreaterThanThreshold();
        // AttackerOne Bid
        vm.startPrank(address(attackerOne));
        uint256 bid1 = .25 ether;
        BetAndAttack.bid{value: bid1}();
        vm.stopPrank();

         // AttackerTwo Bid
        vm.startPrank(address(attackerTwo));
        uint256 bid2 = .25 ether;
        BetAndAttack.bid{value: bid2}();
        vm.stopPrank();

        // Sponsor Withdrawl
        uint256 prevBalance = address(sponsor).balance;
        assertEq(BetAndAttack.sponsorWithdrew(), false); 
        vm.warp(541+duration1); 
        vm.startPrank(address(sponsor));
        BetAndAttack.sponsor_Withdrawl();
        vm.stopPrank(); 

        // Reward = 1 eth
        // AttackerOne .25 eth
        // AttackerTwo .25 eth

        // ResponseTime = 150ms
        // ResponseTimeThreshold = 125ms

        //Outcome Percentage = 100
        // AttackerOne Reward = (.5 + 1 eth) * (100 - 100) = 0 eth
        assertEq(address(sponsor).balance, prevBalance);
        assertEq(BetAndAttack.sponsorWithdrew(), true); 
    }

    function testFail_sponsorWithdrawl_OverWithdrawl() public {
        // ResponseTime < ResponeTimeThreshold
        initContract_ResponseTimeGreaterThanThreshold();

        // AttackerOne Bid
        vm.startPrank(address(attackerOne));
        uint256 bid1 = .25 ether;
        BetAndAttack.bid{value: bid1}();
        vm.stopPrank();

        // AttackerTwo Bid
        vm.startPrank(address(attackerTwo));
        uint256 bid2 = .25 ether;
        BetAndAttack.bid{value: bid2}();
        vm.stopPrank(); 

        // Sponsor Withdrawl
        vm.warp(541+duration1); 
        vm.startPrank(address(sponsor));
        BetAndAttack.sponsor_Withdrawl();
        vm.stopPrank(); 

        // Sponsor Withdrawl (Double Withdrawl )
        vm.warp(545+duration1); 
        vm.startPrank(address(sponsor));
        BetAndAttack.sponsor_Withdrawl();
        vm.stopPrank(); 
    }


   function test_sponsorWithdrawl_PartialReward() public {
       // ResponseTime < ResponeTimeThreshold
       initContract_ResponseTimeLessThanThreshold();
        // AttackerOne Bid
        vm.startPrank(address(attackerOne));
        uint256 bid1 = .25 ether;
        BetAndAttack.bid{value: bid1}();
        vm.stopPrank();

        // AttackerTwo Bid
        vm.startPrank(address(attackerTwo));
        uint256 bid2 = .25 ether;
        BetAndAttack.bid{value: bid2}();
        vm.stopPrank();

        // Sponsor Withdrawl
        uint256 prevBalance = address(sponsor).balance;
        assertEq(BetAndAttack.sponsorWithdrew(), false); 
        vm.warp(541+duration1); 
        vm.startPrank(address(sponsor));
        BetAndAttack.sponsor_Withdrawl();
        vm.stopPrank(); 

        // Reward = 1 eth
        // AttackerOne .25 eth
        // AttackerTwo .25 eth

        // ResponseTime = 150ms
        // ResponseTimeThreshold = 200ms

        //Outcome Percentage = 100
        // AttackerOne Reward = (.5 + 1 eth) * (100 - 75) = .375 eth
        assertEq(address(sponsor).balance, prevBalance + .375 ether);
        assertEq(BetAndAttack.sponsorWithdrew(), true); 
    } 

  function test_attackerWithdawl_Both_PartialReward() public {
        // ResponseTime > ResponeTimeThreshold
        initContract_ResponseTimeLessThanThreshold();
        
        // AttackerOne Bid
         vm.startPrank(address(attackerOne));
        uint256 bid1 = .25 ether;
        BetAndAttack.bid{value: bid1}();
        vm.stopPrank();

        // Balance of AttackerOne after Bid
        uint256 prevBalanceAttackerOne = address(attackerOne).balance;
        
        // AttackerTwoBid
        vm.startPrank(address(attackerTwo));
        uint256 bid2 = .25 ether;
        BetAndAttack.bid{value: bid2}();
        vm.stopPrank();

        // Balance of AttackerTwo after Bid
        uint256 prevBalanceAttackerTwo = address(attackerTwo).balance; 
        //time to withdrawl period duration1 + 540 where 540 = 300 bidEndTime + 240 withdrawlPeriodStart as set in our contract 
        // @dev time must be greater than 540 + duration
        vm.warp(541+duration1);
        vm.startPrank(address(attackerOne));
        BetAndAttack.attacker_withdraw();
        vm.stopPrank(); 

        assertEq(BetAndAttack.balances(address(attackerOne)), 0);
        assertEq(BetAndAttack.balances(address(attackerTwo)), .5 ether - .25 ether);
        // Reward = 1 eth
        // AttackerOne .25 eth
        // AttackerTwo .25 eth

        // ResponseTime = 150ms
        // ResponseTimeThreshold = 200ms

        //Outcome Percentage = 75
        // AttackerOne Reward = (.5 + 1 eth) * (75/100) (.25/.5) = 0.5625 eth
        assertEq(address(attackerOne).balance, prevBalanceAttackerOne + .5625 ether);
        assertEq(address(attackerTwo).balance, .25 ether);
        
        // Attacker Withdrawl (AttackerTwo)
        vm.warp(545+duration1);
        vm.startPrank(address(attackerTwo));
        BetAndAttack.attacker_withdraw();
        vm.stopPrank(); 

        assertEq(BetAndAttack.balances(address(attackerOne)), 0);
        assertEq(BetAndAttack.balances(address(attackerTwo)), 0); 

        assertEq(address(attackerOne).balance, prevBalanceAttackerOne + .5625 ether);
        assertEq(address(attackerTwo).balance, prevBalanceAttackerTwo + .5625 ether);  
  }


 function test_attackerAndSponsorWithdawl_PartialReward() public {
        // ResponseTime > ResponeTimeThreshold
        initContract_ResponseTimeLessThanThreshold();
        
        // AttackerOne Bid
         vm.startPrank(address(attackerOne));
        uint256 bid1 = .25 ether;
        BetAndAttack.bid{value: bid1}();
        vm.stopPrank();

        // Balance of AttackerOne after Bid
        uint256 prevBalanceAttackerOne = address(attackerOne).balance;
        
        // AttackerTwoBid
        vm.startPrank(address(attackerTwo));
        uint256 bid2 = .25 ether;
        BetAndAttack.bid{value: bid2}();
        vm.stopPrank();

        // Balance of AttackerTwo after Bid
        uint256 prevBalanceAttackerTwo = address(attackerTwo).balance; 
        //time to withdrawl period duration1 + 540 where 540 = 300 bidEndTime + 240 withdrawlPeriodStart as set in our contract 
        // @dev time must be greater than 540 + duration
        vm.warp(541+duration1);
        vm.startPrank(address(attackerOne));
        BetAndAttack.attacker_withdraw();
        vm.stopPrank(); 

        assertEq(BetAndAttack.balances(address(attackerOne)), 0);
        assertEq(BetAndAttack.balances(address(attackerTwo)), .5 ether - .25 ether);
        // Reward = 1 eth
        // AttackerOne .25 eth
        // AttackerTwo .25 eth

        // ResponseTime = 150ms
        // ResponseTimeThreshold = 200ms

        //Outcome Percentage = 75
        // AttackerOne Reward = (.5 + 1 eth) * (75/100) (.25/.5) = 0.5625 eth
        assertEq(address(attackerOne).balance, prevBalanceAttackerOne + .5625 ether);
        assertEq(address(attackerTwo).balance, .25 ether);
        
        // Attacker Withdrawl (AttackerTwo)
        vm.warp(545+duration1);
        vm.startPrank(address(attackerTwo));
        BetAndAttack.attacker_withdraw();
        vm.stopPrank(); 

        assertEq(BetAndAttack.balances(address(attackerOne)), 0);
        assertEq(BetAndAttack.balances(address(attackerTwo)), 0); 

        assertEq(address(attackerOne).balance, prevBalanceAttackerOne + .5625 ether);
        assertEq(address(attackerTwo).balance, prevBalanceAttackerTwo + .5625 ether); 

         // Sponsor Withdrawl
        uint256 prevBalance = address(sponsor).balance;
        assertEq(BetAndAttack.sponsorWithdrew(), false); 
        vm.warp(541+duration1); 
        vm.startPrank(address(sponsor));
        BetAndAttack.sponsor_Withdrawl();
        vm.stopPrank(); 

        // Reward = 1 eth
        // AttackerOne .25 eth
        // AttackerTwo .25 eth

        // ResponseTime = 150ms
        // ResponseTimeThreshold = 200ms

        //Outcome Percentage = 100
        // AttackerOne Reward = (.5 + 1 eth) * (100 - 75) = .375 eth
        assertEq(address(sponsor).balance, prevBalance + .375 ether);
        assertEq(BetAndAttack.sponsorWithdrew(), true);  
  }
}
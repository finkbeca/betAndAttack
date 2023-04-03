pragma solidity >= 0.8.0 < 0.9.0;

import "./provableAPI.sol";

/**
 * @title BetAndAttack
 * @dev A contract that allows sponsorship of an attack, attack outcome bidding and withdrawal of funds based on an attack outcome.
 */
contract BetAndAttack is usingProvable {
    
   mapping(address => uint256) public balances;
   uint256 public bidMinimum; // In Wei (1 Ether = 1 wei * (10**18))
   uint256 public responseTimeThreshold; // ResponseTimeThreshold in ms
   uint256 public totalBids; // Total Bids of all Attackers
   address public sponsor; 
   uint256 public reward; // Sponsor's reward
   bool public sponsorWithdrew;
   uint256 public bidEndTime; // Start time
   uint256 public attackEndTime;   // End of Attack
   uint256 public withdrawlPeriodStart; // Start of withdrawl period
   uint256 public outcomePercentage; // Outcome
   uint256 public responseTime; // ResponseTime in ms

   //Events
   event LogConstructorInitiated(string nextStep);
   event LogNewBidder(address bidder, uint256 bid);
   event LogNewWithdraw(address withdrawler, uint256 amount);
   event LogNewProvableQuery(string description);

    /**
    * @dev Initializes the contract with the sponsor's reward and sets the bid minimum and end times.
    * @param duration The duration of the attack period.
    * @param _bidMinimum The minimum bid amount.
    */
   constructor(uint256 duration, uint256 _bidMinimum, uint256 _responseTimeThreshold) public payable {

       sponsor = msg.sender;
       sponsorWithdrew = false;
       responseTimeThreshold = _responseTimeThreshold;
       require(msg.value > 0); // Requires sponsor to set some reward
       reward = msg.value;
       bidMinimum = _bidMinimum;
       totalBids = 0;
       bidEndTime = block.timestamp + 300; // ~5 minutes (TESTING PURPOSES)
       attackEndTime = bidEndTime + duration ;  
       withdrawlPeriodStart = attackEndTime + 240 ; // 9 Minutes + Duration (TESTING PURPOSES)
       emit LogConstructorInitiated("Constructor was initiated. Call 'checkAttackResult()' after the specified duration to see the results of the attack.");

   }

    /**
    * @dev Allows a user to place a bid.
    * @dev bid must be atleast bidMinimum
    */
   function bid() public payable {
       require(msg.value >= bidMinimum);
       require(msg.value > 0);
       require(msg.sender != sponsor); // May not be needed (could also be a problem if wanted to call this contract from some other contract)
       require(block.timestamp < bidEndTime);
       balances[msg.sender] += msg.value;
       totalBids += msg.value;
       emit LogNewBidder(msg.sender, msg.value);
   }

    /**
    * @dev Gets current timestamp
    * @return The current block timestamp.
    */
    function getTime() public view returns(uint256) {
        return block.timestamp;
    }

    /**
    * @dev queries for response time of a specified website, over a specified range of time via a Provable query to the UptimeRobot API.
    */
    function checkAttackResult() public payable  {

        //Note consider restricting # of calls to this function, it could be used the drain the contract funds through unecessary additional calls to the APIs
        // Another option would be to restrict that the post contracts.balance >= prev contract.balane through measuring oracle cost and having msg.sender send additional value to cover gas fees
        // Currently implementation assumes this will be called in good faith but allows sender to send additional funds to cover oracle fees
        require(block.timestamp > attackEndTime);

        if (provable_getPrice("URL") > address(this).balance) {
           emit LogNewProvableQuery("Provable query was NOT sent, please add some ETH to cover for the query fee");
        } else {
           emit LogNewProvableQuery("Provable query was sent, standing by for the answer..");
           provable_query("URL", "json(https://api.uptimerobot.com/v2/getMonitors).monitor[0].average_response_time", 
             '{"data":"api_key=m794019296-c65efbab064db4b4485e16b1&format=json&logs=1&response_times=1&logs_start_date=1648867200&logs_end_date=1648953600", "method":"POST"}');
        }
        
    }

    /**
     * @dev Computes rewards based on the returned responseTime and distributes any rewards to attackers
     */
    function attacker_withdraw() public payable {
        require(block.timestamp > withdrawlPeriodStart);
        require(msg.sender != sponsor);
        
        // amountOut = ((totalBids + award) * attackSuccess ) * (userBid/totalBids)
        if (responseTime > responseTimeThreshold) {
            outcomePercentage = 100;
        } else {
           outcomePercentage = (responseTime * 100)/responseTimeThreshold;
        }

        uint256 amountOut = ((((reward + totalBids) * outcomePercentage) / 100) * balances[msg.sender]) / totalBids;
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(amountOut);

        emit LogNewWithdraw(msg.sender, msg.value);
    }

    /**
     * @dev Computes rewards based on the returned responseTime and distributes any reward to sponsor
     */
    function sponsor_Withdrawl() public payable {
        require(msg.sender == sponsor);
        require(block.timestamp > withdrawlPeriodStart);
        require(sponsorWithdrew == false);

        if (responseTime > responseTimeThreshold) {
            outcomePercentage = 100;
        } else {
           outcomePercentage = (responseTime * 100)/responseTimeThreshold;
        }

        uint256 amountOut = ((reward + totalBids) * (100- outcomePercentage)) / 100;
        sponsorWithdrew = true;
        payable(msg.sender).transfer(amountOut);
        emit LogNewWithdraw(msg.sender, msg.value);
    }

    /**
    * @dev callback for checkAttackResult() that returns the average responseTime over a span of time
    */ 
   function __callback(bytes32 myid, string memory result) public {
       if (msg.sender != provable_cbAddress()) revert();

       /// @dev parseInt floors result
        responseTime = parseInt(result);

   }
}
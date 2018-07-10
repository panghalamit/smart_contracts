pragma solidity ^0.4.19;

contract BettingApp {
	//counter to keep track of betters
    uint n_betters;
    //1st person to place bet amount
    address opp1;
    //person challenging person1
    address opp2;
    //bet amount
    uint amount;
    //nonce for coin toss
    uint counter;
    //precondition bet amount > 0
    modifier positiveAmount(uint val) {
        require(val > 0, "Positive amount needed" );
        _;
    }
    //precondition to make sure new person can start betting
    modifier betPossible {
        require(n_betters < 2, "Bet already in place");
        _;
    }

    constructor() public {
        n_betters = 0;
        counter = 0;
    }
    
    //function that executes bet
    function executeBet() internal {
        counter++;
        bytes32 hashval = keccak256(abi.encodePacked(counter, now, opp1, opp2));
        if(uint256(hashval)%2 == 1) {
            require(opp1.send(amount));
        } else {
            require(opp2.send(amount));
        }
        n_betters=0;
        amount=0;
    }
    
    //external function to call to place a bet and challenge
    function placeBet() public payable betPossible positiveAmount(msg.value) {
        if(n_betters == 0) {
            opp1 = msg.sender;
            amount = msg.value;
            n_betters++;
        } else {
            require(msg.value >= amount, "cant bet less than current"); 
            opp2 = msg.sender;
            uint diff = msg.value - amount; 
            amount *= 2;
            if(msg.sender.send(diff)) {
                n_betters++;
                executeBet();
            } else {
                amount += diff;
            }
        }
        
    }
    
    
}
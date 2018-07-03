pragma solidity ^0.4.19;
contract Counter {
    int private count = 0;
    function incrementCounter() public {
        count += 1;
    }
    function decrementCounter() public {
        count -= 1;
    }
    function getCount() public view returns (int) {
        return count;
    }
    
    function() public payable {
    } 
    
    function withdraw() external {
        require(msg.sender.send(address(this).balance));
    }
}
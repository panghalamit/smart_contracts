pragma solidity ^0.4.0;

contract JointOwnableAccount {
    uint256 public balance = 100000;
    address public owner = msg.sender;
    uint public sig_requirement=2;
    uint private transactions; 
    mapping (address => bool) isPartner;
    mapping (uint => withdraw_request) pendingRequests;
    mapping (uint => mapping(address => bool)) transactionsApprovals;
    address[] public partners;
    
    struct withdraw_request {
        address beneficiary;
        uint amount;
        bool executed;
    }
    
    modifier validateRequirement(uint groupsize, uint numsig) {
        require(groupsize >= numsig && numsig > 0 && groupsize > 0, "Account holders are less than required signatures");
        _;
    }
    
     modifier ownerOnly {
        require(msg.sender == owner, "sender doesnt own the account");
        _;
    }
    modifier checkPartnership {
        require(isPartner[msg.sender], "Sender is not an partner");
        _;
    }
    modifier Exists(uint wr_id) {
        require(pendingRequests[wr_id].beneficiary != 0, "withdraw request doesnt exits");
        _;
    }
    modifier notExecuted(uint wr_id) {
        require(!pendingRequests[wr_id].executed, "transanction already executed");
        _;
    }
    
    modifier partnerExists(address partner){
        require(isPartner[partner], "Partner doesnt exist");
        _;
    }
    
    modifier notAlreadyPartner(address partner) {
        require(!isPartner[partner], "Already a partner");
        _;
    }
    
    constructor (uint opening_balance, address[] _partners, uint _sigrequirement) public validateRequirement(_partners.length+1, _sigrequirement){
        require(opening_balance > 100000, "balance too low to open a account");
        balance = opening_balance;
        partners.push(msg.sender);
        owner = msg.sender;
        isPartner[owner] = true;
        for(uint i=0; i<_partners.length; i++) {
            partners.push(_partners[i]);
            isPartner[_partners[i]]=true;
        }
    }
    
    /// @dev Fallback function allows to deposit ether.
    function()
        public payable 
    {
        if (msg.value > 0)
            balance+=msg.value;
    }
        
    function changeRequirement(uint num_signatures) public ownerOnly validateRequirement(partners.length, num_signatures){
        sig_requirement=num_signatures;
    }
    function transferOwnership(address newOwner) public ownerOnly partnerExists(newOwner){
        for(uint i=1; i<partners.length; i++) {
            if(newOwner == partners[i]) {
                partners[i] = owner;
                owner = newOwner;
                partners[0] = owner;
                break;
            }
        }
    }
    function addNewPartner(address partner) public ownerOnly notAlreadyPartner(partner){
        partners.push(partner);
        isPartner[partner] = true;
    }
    
    function removePartner(address partner) public ownerOnly validateRequirement(partners.length-1, sig_requirement) {
        isPartner[partner] = false;
        for (uint i=1; i<partners.length - 1; i++)
            if (partners[i] == partner) {
                partners[i] = partners[partners.length - 1];
                break;
            }
        partners.length -= 1;
    }
    function withdraw(uint amount) public ownerOnly {
        require(amount <= balance);
        balance -= amount;
        msg.sender.transfer(amount);
    }
    
    function withdrawRequest(uint amount) public checkPartnership returns (uint wid) {
        wid = 0;
        if(msg.sender == owner) {
            withdraw(amount);
        }
        else {
            wid = addTransaction(amount, msg.sender);
        }
        return wid;
    } 
    
    function approveWithdrawRequest(uint wr_id) checkPartnership Exists(wr_id) notExecuted(wr_id) public {
        transactionsApprovals[wr_id][msg.sender] = true;
    } 
    
    function revokeWithdrawRequest(uint wr_id) checkPartnership Exists(wr_id) notExecuted(wr_id) public {
        transactionsApprovals[wr_id][msg.sender] = false;
    }
    
    function addTransaction(uint value, address recipient) internal returns (uint transactionId) {
        transactionId = transactions;
        pendingRequests[transactionId] = withdraw_request({
            beneficiary: recipient,
            amount: value,
            executed: false
        });
        transactions += 1;
        return transactionId;
    }
    
    function executeTransaction(uint wr_id) checkPartnership Exists(wr_id) notExecuted(wr_id) public {
        if(isConfirmed(wr_id)) {
            require(balance >= pendingRequests[wr_id].amount, "Account doesnt have enough balance");
            balance-=pendingRequests[wr_id].amount;
            pendingRequests[wr_id].executed=true;
            pendingRequests[wr_id].beneficiary.transfer(pendingRequests[wr_id].amount);
        }
    }
    
    function isConfirmed(uint wr_id) notExecuted(wr_id) internal constant returns (bool){
        uint count = 0;
        for (uint i=0; i<partners.length; i++) {
            if (transactionsApprovals[wr_id][partners[i]])
                count += 1;
            if (count == sig_requirement)
                return true;
        }
        return false;
    }
}
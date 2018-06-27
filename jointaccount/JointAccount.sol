pragma solidity ^0.4.0;

contract JointOwnableAccount {
    
    //Add Events to interact with frontend : self-explanatory
    
    event OwnershipChanged(address old_owner, address new_owner);
    event RequirementChanged(uint old_req, uint new_req);
    event PartnerAdded(address new_partner);
    event PartnerRemoved(address old_partner);
    event Withdrawal(uint amount, uint remaining_balance, address beneficiary);
    event WithdrawalRequest(uint amount, address requestor);
    event ApprovalConfirmation(uint req_id, address approver);
    event ApprovalRevocation(uint req_id, address revoker);
    
    // balance of the account
    uint256 public balance = 100000;
    
    // primary owner, initially the contract creator
    address public owner = msg.sender;
    
    // minimum signature requirement for approval of withdrawal requests of secondary partners
    uint public sig_requirement=2;
    
    // counter to ensure unique ids to withdrawal requests
    uint private transactions; 
    
    // mapping to keep track of memberships of addresses 
    mapping (address => bool) isPartner;
    
    // mapping of withdrawal request id to the request, to keep track of requests
    mapping (uint => withdraw_request) pendingRequests;
    
    // mapping to keep track of signatures for withdrawal request by secondary partners
    mapping (uint => mapping(address => bool)) transactionsApprovals;
    
    // Array of addresses of partners, partners[0] is primary owner/partner
    address[] public partners;
    
    // data structure for storing withdrawal requests from secondary partners    
    struct withdraw_request {
        address beneficiary;
        uint amount;
        bool executed;
    }
    
    // pre-condition for sanity check of num of signatures required to approve request from secondary partners
    modifier validateRequirement(uint groupsize, uint numsig) {
        require(groupsize >= numsig && numsig > 0 && groupsize > 0, "Account holders are less than required signatures");
        _;
    }
    
    // pre-condition for ownership check 
    modifier ownerOnly {
        require(msg.sender == owner, "sender doesnt own the account");
        _;
    }
    
    // pre-condition for partnership check
    modifier checkPartnership {
        require(isPartner[msg.sender], "Sender is not an partner");
        _;
    }
    
    //pre-condition to check if a withdrawal request with given id exists
    modifier Exists(uint wr_id) {
        require(pendingRequests[wr_id].beneficiary != 0, "withdraw request doesnt exits");
        _;
    }
    
    //pre-condition to check if a given withdrawal request already been processed/executed
    modifier notExecuted(uint wr_id) {
        require(!pendingRequests[wr_id].executed, "transanction already executed");
        _;
    }
    
    //pre-condition to check if given address is already a partner
    modifier partnerExists(address partner){
        require(isPartner[partner], "Partner doesnt exist");
        _;
    }
    
    //pre-condition to check if a given address is not a partner
    modifier notAlreadyPartner(address partner) {
        require(!isPartner[partner], "Already a partner");
        _;
    }
    
    // constructor initializes opening balance, owner and secondary partners, and requirement for secondary partners
    constructor (uint opening_balance, address[] _partners, uint _sigrequirement) public validateRequirement(_partners.length+1, _sigrequirement){
        require(opening_balance > 100000, "balance too low to open a account");
        balance = opening_balance;
        partners.push(msg.sender);
        owner = msg.sender;
        isPartner[owner] = true;
        for(uint i=0; i<_partners.length; i++) {
            partners.push(_partners[i]);
            isPartner[_partners[i]]=true;
            emit PartnerAdded(_partners[i]);
        }
    }
    
    // Fallback function allows to deposit ether.
    function()
        public payable 
    {
        if (msg.value > 0)
            balance+=msg.value;
    }
        
    // function to change requirement , only owner can access    
    function changeRequirement(uint num_signatures) public ownerOnly validateRequirement(partners.length, num_signatures){
        emit RequirementChanged(sig_requirement, num_signatures);
        sig_requirement=num_signatures;
    }
    
    // function to transferOwnership to one of the secondary partner
    function transferOwnership(address newOwner) public ownerOnly partnerExists(newOwner){
        for(uint i=1; i<partners.length; i++) {
            if(newOwner == partners[i]) {
                partners[i] = owner;
                owner = newOwner;
                partners[0] = owner;
                emit OwnershipChanged(partners[i], newOwner);
                break;
            }
        }
    }
    
    //function to view all pendingRequests 
    function getPendingRequests() public checkPartnership constant returns (uint[] memory pending) {
        uint count=0;
        for(uint i=0; i<transactions; i++) {
            if(!pendingRequests[i].executed && pendingRequests[i].beneficiary != 0) 
                count++;
        }
        pending = new uint[](count);
        count=0;
        for(uint j=0; j<transactions; j++) {
            if(!pendingRequests[j].executed && pendingRequests[j].beneficiary != 0)
                pending[count++] = j;
        }
    }
    
    // function to add a new secondary partner : only owner can access
    function addNewPartner(address partner) public ownerOnly notAlreadyPartner(partner){
        partners.push(partner);
        emit PartnerAdded(partner);
        isPartner[partner] = true;
    }
    
    // function to remove a secondary partner : only owner can access
    function removePartner(address partner) public ownerOnly validateRequirement(partners.length-1, sig_requirement) {
        isPartner[partner] = false;
        for (uint i=1; i<partners.length - 1; i++)
            if (partners[i] == partner) {
                partners[i] = partners[partners.length - 1];
                emit PartnerRemoved(partner);
                break;
            }
        partners.length -= 1;
    }
    
    // function to withdraw sum out of account : only owner can access
    function withdraw(uint amount) public ownerOnly {
        assert(amount <= balance);
        balance -= amount;
        if(!msg.sender.send(amount)) {
            balance += amount;
        } else {
            emit Withdrawal(amount, balance, msg.sender);
        }
    }
    
    // function to create a withdrawal request by a secondary partner
    function withdrawRequest(uint amount) public checkPartnership returns (uint wid) {
        wid = 0;
        if(msg.sender == owner) {
            withdraw(amount);
        }
        else {
            wid = addTransaction(amount, msg.sender);
        }
    } 
    
    // function to approve a withdraw request with a given id : only partners can access
    function approveWithdrawRequest(uint wr_id) checkPartnership Exists(wr_id) notExecuted(wr_id) public {
        transactionsApprovals[wr_id][msg.sender] = true;
        emit ApprovalConfirmation(wr_id, msg.sender);
    } 
    
    // function to revoke a withdraw request with a given id : only partners can access
    function revokeWithdrawRequest(uint wr_id) checkPartnership Exists(wr_id) notExecuted(wr_id) public {
        transactionsApprovals[wr_id][msg.sender] = false;
        emit ApprovalRevocation(wr_id, msg.sender);
    }
    
    // internal function to add request to pending list
    function addTransaction(uint value, address recipient) internal returns (uint transactionId) {
        transactionId = transactions;
        pendingRequests[transactionId] = withdraw_request({
            beneficiary: recipient,
            amount: value,
            executed: false
        });
        emit WithdrawalRequest(value, recipient);
        transactions += 1;
    }
    
    // function to execute a withdraw request if is has required number of approvals, is not already executed : only partners can access
    function executeTransaction(uint wr_id) checkPartnership Exists(wr_id) notExecuted(wr_id) public {
        if(isConfirmed(wr_id)) {
            require(balance >= pendingRequests[wr_id].amount, "Account doesnt have enough balance");
            balance-=pendingRequests[wr_id].amount;
            pendingRequests[wr_id].executed=true;
            if(!pendingRequests[wr_id].beneficiary.send(pendingRequests[wr_id].amount)) {
                balance+=pendingRequests[wr_id].amount;
            } else {
                emit Withdrawal(pendingRequests[wr_id].amount, balance, pendingRequests[wr_id].beneficiary);
            }
        }
    }
    
    // internal function to check if a given request has required number of approvals
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
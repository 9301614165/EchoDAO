// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title EchoDAO
 * @dev A decentralized autonomous organization for community governance
 * @notice This contract enables transparent proposal creation, voting, and execution
 */
contract EchoDAO {
    // State variables
    address public owner;
    uint256 public proposalCounter;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTES_REQUIRED = 10;
    
    // Structs
    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        bool active;
    }
    
    struct Member {
        bool isActive;
        uint256 votingPower;
        uint256 joinedAt;
    }
    
    // Mappings
    mapping(uint256 => Proposal) public proposals;
    mapping(address => Member) public members;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    
    // Arrays
    address[] public membersList;
    
    // Events
    event ProposalCreated(uint256 indexed proposalId, string title, address indexed proposer);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId, bool success);
    event MemberAdded(address indexed member, uint256 votingPower);
    event MemberUpdated(address indexed member, uint256 newVotingPower);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyMember() {
        require(members[msg.sender].isActive, "Only active members can call this function");
        _;
    }
    
    modifier proposalExists(uint256 _proposalId) {
        require(_proposalId < proposalCounter, "Proposal does not exist");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        proposalCounter = 0;
        
        // Add owner as first member with maximum voting power
        members[msg.sender] = Member({
            isActive: true,
            votingPower: 100,
            joinedAt: block.timestamp
        });
        membersList.push(msg.sender);
        
        emit MemberAdded(msg.sender, 100);
    }
    
    /**
     * @dev Core Function 1: Create a new proposal
     * @param _title The title of the proposal
     * @param _description Detailed description of the proposal
     */
    function createProposal(string memory _title, string memory _description) 
        external 
        onlyMember 
        returns (uint256) 
    {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        uint256 proposalId = proposalCounter;
        proposals[proposalId] = Proposal({
            id: proposalId,
            title: _title,
            description: _description,
            proposer: msg.sender,
            votesFor: 0,
            votesAgainst: 0,
            deadline: block.timestamp + VOTING_PERIOD,
            executed: false,
            active: true
        });
        
        proposalCounter++;
        
        emit ProposalCreated(proposalId, _title, msg.sender);
        return proposalId;
    }
    
    /**
     * @dev Core Function 2: Vote on a proposal
     * @param _proposalId The ID of the proposal to vote on
     * @param _support True for yes, false for no
     */
    function vote(uint256 _proposalId, bool _support) 
        external 
        onlyMember 
        proposalExists(_proposalId) 
    {
        Proposal storage proposal = proposals[_proposalId];
        
        require(proposal.active, "Proposal is not active");
        require(block.timestamp < proposal.deadline, "Voting period has ended");
        require(!hasVoted[_proposalId][msg.sender], "Already voted on this proposal");
        
        uint256 votingPower = members[msg.sender].votingPower;
        hasVoted[_proposalId][msg.sender] = true;
        
        if (_support) {
            proposal.votesFor += votingPower;
        } else {
            proposal.votesAgainst += votingPower;
        }
        
        emit VoteCast(_proposalId, msg.sender, _support, votingPower);
    }
    
    /**
     * @dev Core Function 3: Execute a proposal after voting period
     * @param _proposalId The ID of the proposal to execute
     */
    function executeProposal(uint256 _proposalId) 
        external 
        proposalExists(_proposalId) 
        returns (bool) 
    {
        Proposal storage proposal = proposals[_proposalId];
        
        require(proposal.active, "Proposal is not active");
        require(block.timestamp >= proposal.deadline, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        require(totalVotes >= MIN_VOTES_REQUIRED, "Not enough votes to execute");
        
        bool success = proposal.votesFor > proposal.votesAgainst;
        proposal.executed = true;
        proposal.active = false;
        
        emit ProposalExecuted(_proposalId, success);
        return success;
    }
    
    // Administrative functions
    
    /**
     * @dev Add a new member to the DAO
     * @param _member Address of the new member
     * @param _votingPower Voting power to assign to the member
     */
    function addMember(address _member, uint256 _votingPower) external onlyOwner {
        require(_member != address(0), "Invalid member address");
        require(!members[_member].isActive, "Member already exists");
        require(_votingPower > 0 && _votingPower <= 100, "Invalid voting power");
        
        members[_member] = Member({
            isActive: true,
            votingPower: _votingPower,
            joinedAt: block.timestamp
        });
        membersList.push(_member);
        
        emit MemberAdded(_member, _votingPower);
    }
    
    /**
     * @dev Update member's voting power
     * @param _member Address of the member
     * @param _newVotingPower New voting power to assign
     */
    function updateMemberVotingPower(address _member, uint256 _newVotingPower) external onlyOwner {
        require(members[_member].isActive, "Member does not exist");
        require(_newVotingPower > 0 && _newVotingPower <= 100, "Invalid voting power");
        
        members[_member].votingPower = _newVotingPower;
        
        emit MemberUpdated(_member, _newVotingPower);
    }
    
    // View functions
    
    /**
     * @dev Get proposal details
     * @param _proposalId The ID of the proposal
     */
    function getProposal(uint256 _proposalId) 
        external 
        view 
        proposalExists(_proposalId) 
        returns (
            string memory title,
            string memory description,
            address proposer,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 deadline,
            bool executed,
            bool active
        ) 
    {
        Proposal memory proposal = proposals[_proposalId];
        return (
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.deadline,
            proposal.executed,
            proposal.active
        );
    }
    
    /**
     * @dev Get member details
     * @param _member Address of the member
     */
    function getMember(address _member) 
        external 
        view 
        returns (bool isActive, uint256 votingPower, uint256 joinedAt) 
    {
        Member memory member = members[_member];
        return (member.isActive, member.votingPower, member.joinedAt);
    }
    
    /**
     * @dev Get total number of members
     */
    function getTotalMembers() external view returns (uint256) {
        return membersList.length;
    }
    
    /**
     * @dev Get all active proposals count
     */
    function getActiveProposalsCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < proposalCounter; i++) {
            if (proposals[i].active) {
                count++;
            }
        }
        return count;
    }
}

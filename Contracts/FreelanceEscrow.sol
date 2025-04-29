// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./SafePayment.sol";
import "./IEscrow.sol";
import "./IArbitration.sol";

/// @title A Decentralized Freelance Escrow with Staked Arbitration
contract FreelanceEscrow is
    ReentrancyGuard,
    AccessControl,
    IEscrow,
    IArbitration
{
    using SafePayment for address payable;

    // Roles & parameters
    bytes32 public constant ARBITRATOR_ROLE = keccak256("ARBITRATOR");
    uint256 public constant REQUIRED_STAKE = 1 ether;
    uint256 public constant VOTE_THRESHOLD = 3;

    enum State { Posted, Accepted, Submitted, Completed, Disputed, Resolved }
    struct Job {
        address client;
        address freelancer;
        uint256 amount;
        State state;
        uint256 clientVotes;
        uint256 freelancerVotes;
        uint256 acceptTimestamp; 
        uint256 disputeTimestamp;
    }

    // Storage
    mapping(uint256 => Job) public jobs;
    mapping(address => uint256) public arbitratorStakes;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => bool)) public voteChoice;
    mapping(uint256 => address[]) public voters;
    mapping(address => uint256) public lockedStakes;
    uint256 public nextJobId;

    // Events
    event JobPosted(uint256 indexed jobId, address indexed client, uint256 amount);
    event JobWithdrawn(uint256 indexed jobId, address indexed client);
    event JobAccepted(uint256 indexed jobId, address indexed freelancer);
    event WorkSubmitted(uint256 indexed jobId);
    event JobCancelled(uint256 indexed jobId, address indexed caller);
    event JobCompleted(uint256 indexed jobId);
    event JobDeleted(uint256 indexed jobId);
    event DisputeRaised(uint256 indexed jobId);
    event Voted(uint256 indexed jobId, address indexed arbitrator, bool clientWins);
    event DisputeResolved(uint256 indexed jobId, address indexed winner);
    event DisputeExpired(uint256 indexed jobId);
    event Staked(address indexed arbitrator, uint256 amount);
    event Unstaked(address indexed arbitrator, uint256 amount);

    /// @notice Setup roles for deployer
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ARBITRATOR_ROLE, msg.sender);
    }

    uint256 public constant MAX_VOTERS = 10;

    /// @notice Client posts a job by depositing ETH
    function postJob() external payable override returns (uint256 jobId) {
        require(msg.value > 0, "Must fund job");
        jobId = nextJobId++;
        jobs[jobId] = Job({
            client: msg.sender,
            freelancer: address(0),
            amount: msg.value,
            state: State.Posted,
            clientVotes: 0,
            freelancerVotes: 0,
            acceptTimestamp: 0,
            disputeTimestamp: 0
        });

        emit JobPosted(jobId, msg.sender, msg.value);
    }

    /// @notice Client can cancel a job before anyone accepts it
    function withdrawJob(uint256 jobId) external nonReentrant {
        Job storage j = jobs[jobId];
        require(j.client == msg.sender, "Not your job");
        require(j.state == State.Posted, "Already taken");
        j.state = State.Resolved;
        uint256 amount = j.amount;
        j.amount = 0;
        payable(msg.sender).pullPayment(amount);
        emit JobWithdrawn(jobId, msg.sender);
    }

    /// @notice Freelancer accepts the job
    function acceptJob(uint256 jobId) external override {
        Job storage j = jobs[jobId];
        require(j.client != address(0), "Job does not exist");
        require(j.state == State.Posted, "Not open");
        j.freelancer = msg.sender;
        j.acceptTimestamp = block.timestamp;
        j.state = State.Accepted;
        emit JobAccepted(jobId, msg.sender);
    }

    uint256 public constant SUBMIT_WINDOW = 7 days;

    function cancelAfterAccept(uint256 jobId) external nonReentrant {
        Job storage j = jobs[jobId];
        require(block.timestamp >= j.acceptTimestamp + SUBMIT_WINDOW, "Too early to cancel");
        require(j.client == msg.sender, "Only client");
        require(j.state == State.Accepted, "Not accepted");
        require(block.timestamp >= j.acceptTimestamp + SUBMIT_WINDOW,
                "Too early to cancel");
        
        // Mark resolved and refund client
        j.state = State.Resolved;
        uint256 amt = j.amount;
        j.amount = 0;
        payable(j.client).pullPayment(amt);

    
        emit JobCancelled(jobId, msg.sender);
        emit JobDeleted(jobId);
    }

    /// @notice Freelancer submits work
    function submitWork(uint256 jobId) external override {
        Job storage j = jobs[jobId];
        require(j.client != address(0), "Job does not exist");
        require(j.freelancer == msg.sender && j.state == State.Accepted, "Forbidden");
        j.state = State.Submitted;
        emit WorkSubmitted(jobId);
    }

    /// @notice Client confirms completion and releases funds
    function confirmCompletion(uint256 jobId)
        external
        nonReentrant
        override
    {
        Job storage j = jobs[jobId];
        require(j.client != address(0), "Job does not exist");
        require(j.client == msg.sender && j.state == State.Submitted, "Forbidden");
        j.state = State.Completed;
        payable(j.freelancer).pullPayment(j.amount);
        emit JobCompleted(jobId);
    }

    uint256 public constant AUTO_COMPLETE_DELAY = 3 days;

    /// @notice Freelancer can auto-complete if client doesn’t confirm in time
    function autoConfirm(uint256 jobId) external nonReentrant {
        Job storage j = jobs[jobId];
        require(j.freelancer == msg.sender, "Only freelancer");
        require(j.state == State.Submitted, "Not submitted");
        require(block.timestamp >= j.acceptTimestamp + AUTO_COMPLETE_DELAY,
                "Too early");
        j.state = State.Completed;
        payable(j.freelancer).pullPayment(j.amount);
        emit JobCompleted(jobId);
    }

    /// @notice Raise a dispute on a submitted job
    function raiseDispute(uint256 jobId) external override {
        Job storage j = jobs[jobId];
        require(j.client != address(0), "Job does not exist");
        require(
            (j.client == msg.sender || j.freelancer == msg.sender) &&
            j.state == State.Submitted,
            "Forbidden"
        );
        j.state = State.Disputed;
        j.disputeTimestamp = block.timestamp;
        emit DisputeRaised(jobId);
    }

    /// @notice IArbitration entrypoint calls into voteDispute
    function arbitrate(uint256 jobId, bool clientWins)
        external
        override
        onlyRole(ARBITRATOR_ROLE)
    {
        voteDispute(jobId, clientWins);
    }

    mapping(address => uint256) public stakeTimestamp;

    /// @notice Arbitrator stakes ETH to participate
    function stake() external payable {
        require(msg.value >= REQUIRED_STAKE, "Must stake >= 1 ETH");
        arbitratorStakes[msg.sender] += msg.value;
        stakeTimestamp[msg.sender] = block.timestamp;
        emit Staked(msg.sender, msg.value);
    }

    /// @notice Arbitrator withdraws their stake
    function unstake(uint256 amount) external nonReentrant {
        uint256 availableStake = arbitratorStakes[msg.sender] - lockedStakes[msg.sender];
        require(
            availableStake >= amount,
            "Insufficient available stake"
        );
        arbitratorStakes[msg.sender] -= amount;
        uint256 total = arbitratorStakes[msg.sender];
        uint256 locked = lockedStakes[msg.sender];
        require(total - locked >= amount, "Insufficient available stake");

        arbitratorStakes[msg.sender] = total - amount;
        payable(msg.sender).pullPayment(amount);
        emit Unstaked(msg.sender, amount);
    }

    /// @notice Vote in a dispute
    function voteDispute(uint256 jobId, bool clientWins)
        public
        onlyRole(ARBITRATOR_ROLE)
        nonReentrant
    {
        Job storage j = jobs[jobId];
        require(j.state == State.Disputed, "No dispute");
        require(voters[jobId].length < MAX_VOTERS, "Too many voters");

        require(
            msg.sender != j.client && msg.sender != j.freelancer,
            "Client/freelancer cannot vote"
        );

        require(
            block.timestamp >= stakeTimestamp[msg.sender] + 1 hours,
            "Must wait after staking"
        );



        require(j.client != address(0), "Job does not exist");
        require(j.state == State.Disputed, "No dispute");
        require(!hasVoted[jobId][msg.sender], "Already voted");
        require(
            arbitratorStakes[msg.sender] - lockedStakes[msg.sender] >= REQUIRED_STAKE,
            "Insufficient available stake"
        );

        // Record & lock stake
        hasVoted[jobId][msg.sender] = true;
        voteChoice[jobId][msg.sender] = clientWins;
        voters[jobId].push(msg.sender);
        lockedStakes[msg.sender] += REQUIRED_STAKE;

        // Tally & emit vote
        if (clientWins) j.clientVotes++; else j.freelancerVotes++;
        emit Voted(jobId, msg.sender, clientWins);

        // Resolve if threshold reached
        if (j.clientVotes + j.freelancerVotes >= VOTE_THRESHOLD) {
            _resolveDispute(jobId);
        }
    }

    uint256 public constant DISPUTE_WINDOW = 2 days;

    function resolveOverdue(uint256 jobId) external nonReentrant {
        Job storage j = jobs[jobId];
        require(j.state == State.Disputed, "Not in dispute");
        require(block.timestamp >= j.disputeTimestamp + DISPUTE_WINDOW,
                "Too early");
        // Return all locked stakes to voters
        address[] memory voterList = voters[jobId];
        for (uint i; i < voterList.length; i++) {
            address v = voterList[i];
            lockedStakes[v] -= REQUIRED_STAKE;
            payable(v).pullPayment(REQUIRED_STAKE);
        }
        delete voters[jobId];
        j.state = State.Resolved;
        emit DisputeExpired(jobId);
    }

    /// @dev Internal dispute resolution
    function _resolveDispute(uint256 jobId) internal {
        Job storage j = jobs[jobId];
        bool clientWins = j.clientVotes > j.freelancerVotes;
        address winner = clientWins ? j.client : j.freelancer;

        j.state = State.Resolved;
        address[] memory voterList = voters[jobId];

        uint256 slashPool = 0;
        for (uint i; i < voterList.length; i++) {
            address v = voterList[i];
            lockedStakes[v] -= REQUIRED_STAKE;

            if (voteChoice[jobId][v] != clientWins) {
                arbitratorStakes[v] -= REQUIRED_STAKE;
                slashPool += REQUIRED_STAKE;
            }
        }

        uint256 honestCount = clientWins ? j.clientVotes : j.freelancerVotes;
        for (uint i = 0; i < voterList.length; i++) {
            address v = voterList[i];
            if (voteChoice[jobId][v] == clientWins) {
                arbitratorStakes[v] -= REQUIRED_STAKE;
                payable(v).pullPayment(REQUIRED_STAKE);
            }
        }

        if (honestCount > 0 && slashPool > 0) {
            uint256 bonus = slashPool / honestCount;
            uint256 remainder = slashPool % honestCount;
            uint256 honestPaid = 0;

            for (uint i = 0; i < voterList.length; i++) {
                address v = voterList[i];
                if (voteChoice[jobId][v] == clientWins) {
                    uint256 payout = bonus;
                    if (honestPaid == honestCount - 1) {
                    payout += remainder;
                    }
                    payable(v).pullPayment(bonus);
                    honestPaid++;
                }
            }
        }


        payable(winner).pullPayment(j.amount);
        emit DisputeResolved(jobId, winner);
        delete voters[jobId];
        }

        /// @notice Admin grants arbitrator role to an account
    function grantArbitratorRole(address account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        grantRole(ARBITRATOR_ROLE, account);
    }

    /// @notice Accept direct ETH transfers (ignored)
    receive() external payable {}
}

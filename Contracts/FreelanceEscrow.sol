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
    event JobAccepted(uint256 indexed jobId, address indexed freelancer);
    event WorkSubmitted(uint256 indexed jobId);
    event JobCompleted(uint256 indexed jobId);
    event DisputeRaised(uint256 indexed jobId);
    event Voted(uint256 indexed jobId, address indexed arbitrator, bool clientWins);
    event DisputeResolved(uint256 indexed jobId, address indexed winner);
    event Staked(address indexed arbitrator, uint256 amount);
    event Unstaked(address indexed arbitrator, uint256 amount);

    /// @notice Setup roles for deployer
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ARBITRATOR_ROLE, msg.sender);
    }

    /// @notice Client posts a job by depositing ETH
    function postJob() external payable override returns (uint256 jobId) {
        require(msg.value > 0, "Must fund job");
        jobId = nextJobId++;
        jobs[jobId] = Job(msg.sender, address(0), msg.value, State.Posted, 0, 0);
        emit JobPosted(jobId, msg.sender, msg.value);
    }

    /// @notice Freelancer accepts the job
    function acceptJob(uint256 jobId) external override {
        Job storage j = jobs[jobId];
        require(j.client != address(0), "Job does not exist");
        require(j.state == State.Posted, "Not open");
        j.freelancer = msg.sender;
        j.state = State.Accepted;
        emit JobAccepted(jobId, msg.sender);
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

    /// @notice Arbitrator stakes ETH to participate
    function stake() external payable {
        require(msg.value >= REQUIRED_STAKE, "Must stake >= 1 ETH");
        arbitratorStakes[msg.sender] += msg.value;
        emit Staked(msg.sender, msg.value);
    }

    /// @notice Arbitrator withdraws their stake
    function unstake(uint256 amount) external nonReentrant {
        uint256 availableStake = arbitratorStakes[msg.sender] - lockedStakes[msg.sender];
        require(availableStake >= amount, "Insufficient available stake");
        arbitratorStakes[msg.sender] -= amount;
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

    /// @dev Internal dispute resolution
    function _resolveDispute(uint256 jobId) internal {
        Job storage j = jobs[jobId];
        bool clientWins = j.clientVotes > j.freelancerVotes;
        address winner = clientWins ? j.client : j.freelancer;

        j.state = State.Resolved;
        address[] memory voterList = voters[jobId];

        // Slash losing stakes and unlock
        for (uint256 i; i < voterList.length; i++) {
            address voter = voterList[i];
            lockedStakes[voter] -= REQUIRED_STAKE;
            if (voteChoice[jobId][voter] != clientWins) {
                arbitratorStakes[voter] -= REQUIRED_STAKE;
                payable(winner).pullPayment(REQUIRED_STAKE);
            }
        }
        delete voters[jobId];

        // Release escrow amount
        payable(winner).pullPayment(j.amount);
        emit DisputeResolved(jobId, winner);
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

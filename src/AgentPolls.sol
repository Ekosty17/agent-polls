// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Agent Polls — on-chain voting where 1 Agent ID = 1 vote.
/// @notice Only addresses holding an Agent ID (SPACE ID Agent ID, ERC-721,
///         0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F on BNB Chain) can create
///         polls and vote. One vote per Agent ID per poll, votes are final
///         and transparent. No token, no rewards, no fees, no owner, no
///         admin functions. The contract holds no funds and cannot move any
///         user's assets. Gating follows the hackathon announcement exactly:
///         balanceOf(address) > 0 means the address holds an Agent ID.
interface IAgentIdRegistry {
    function balanceOf(address account) external view returns (uint256);
}

contract AgentPolls {
    IAgentIdRegistry public immutable agentId;

    uint256 public constant MIN_OPTIONS = 2;
    uint256 public constant MAX_OPTIONS = 6;
    uint256 public constant MIN_DURATION = 1 hours;
    uint256 public constant MAX_DURATION = 90 days;

    struct Poll {
        address creator;
        string question;
        string[] options;
        uint256 deadline;
        uint256[] votes;
        uint256 totalVotes;
    }

    Poll[] private polls;
    mapping(uint256 => mapping(address => bool)) private hasVoted;
    mapping(uint256 => mapping(address => uint8)) private voteOf;

    event PollCreated(
        uint256 indexed pollId,
        address indexed creator,
        string question,
        uint256 deadline,
        uint256 optionCount
    );
    event VoteCast(uint256 indexed pollId, address indexed voter, uint8 indexed optionIndex);

    error NotAgentIdHolder(address account);
    error InvalidOptionCount(uint256 count);
    error EmptyQuestion();
    error EmptyOption(uint256 index);
    error InvalidDuration(uint256 durationSeconds);
    error PollNotFound(uint256 pollId);
    error PollClosed(uint256 pollId);
    error AlreadyVoted(uint256 pollId, address voter);
    error InvalidOption(uint256 pollId, uint256 optionIndex);

    /// @param agentIdRegistry The Agent ID registry (SPACE ID Agent ID).
    ///        On BNB Chain mainnet this is 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F.
    constructor(address agentIdRegistry) {
        agentId = IAgentIdRegistry(agentIdRegistry);
    }

    modifier onlyAgentIdHolder() {
        if (agentId.balanceOf(msg.sender) == 0) revert NotAgentIdHolder(msg.sender);
        _;
    }

    /// @notice True when `account` holds at least one Agent ID.
    function isAgentIdHolder(address account) public view returns (bool) {
        return agentId.balanceOf(account) > 0;
    }

    function pollCount() public view returns (uint256) {
        return polls.length;
    }

    /// @notice Create a poll. Only Agent ID holders. 2-6 options, duration 1h-90d.
    function createPoll(string calldata question, string[] calldata options, uint256 durationSeconds)
        external
        onlyAgentIdHolder
        returns (uint256 pollId)
    {
        if (bytes(question).length == 0) revert EmptyQuestion();
        if (options.length < MIN_OPTIONS || options.length > MAX_OPTIONS) {
            revert InvalidOptionCount(options.length);
        }
        if (durationSeconds < MIN_DURATION || durationSeconds > MAX_DURATION) {
            revert InvalidDuration(durationSeconds);
        }
        for (uint256 i = 0; i < options.length; i++) {
            if (bytes(options[i]).length == 0) revert EmptyOption(i);
        }
        pollId = polls.length;
        Poll storage p = polls.push();
        p.creator = msg.sender;
        p.question = question;
        p.deadline = block.timestamp + durationSeconds;
        for (uint256 i = 0; i < options.length; i++) {
            p.options.push(options[i]);
            p.votes.push(0);
        }
        emit PollCreated(pollId, msg.sender, question, p.deadline, options.length);
    }

    /// @notice Cast one vote. One vote per Agent ID per poll, final, transparent.
    function vote(uint256 pollId, uint8 optionIndex) external onlyAgentIdHolder {
        if (pollId >= polls.length) revert PollNotFound(pollId);
        Poll storage p = polls[pollId];
        if (block.timestamp >= p.deadline) revert PollClosed(pollId);
        if (hasVoted[pollId][msg.sender]) revert AlreadyVoted(pollId, msg.sender);
        if (optionIndex >= p.options.length) revert InvalidOption(pollId, optionIndex);
        hasVoted[pollId][msg.sender] = true;
        voteOf[pollId][msg.sender] = optionIndex;
        p.votes[optionIndex] += 1;
        p.totalVotes += 1;
        emit VoteCast(pollId, msg.sender, optionIndex);
    }

    // ---- Flat read helpers, so a plain JSON-RPC frontend can decode them ----

    function getPollMeta(uint256 pollId)
        external
        view
        returns (
            address creator,
            string memory question,
            uint256 deadline,
            uint256 totalVotes,
            uint256 optionCount
        )
    {
        if (pollId >= polls.length) revert PollNotFound(pollId);
        Poll storage p = polls[pollId];
        return (p.creator, p.question, p.deadline, p.totalVotes, p.options.length);
    }

    function getOption(uint256 pollId, uint256 optionIndex) external view returns (string memory) {
        if (pollId >= polls.length) revert PollNotFound(pollId);
        Poll storage p = polls[pollId];
        if (optionIndex >= p.options.length) revert InvalidOption(pollId, optionIndex);
        return p.options[optionIndex];
    }

    function getOptionVotes(uint256 pollId, uint256 optionIndex) external view returns (uint256) {
        if (pollId >= polls.length) revert PollNotFound(pollId);
        Poll storage p = polls[pollId];
        if (optionIndex >= p.options.length) revert InvalidOption(pollId, optionIndex);
        return p.votes[optionIndex];
    }

    function getResults(uint256 pollId) external view returns (uint256[] memory votes, uint256 totalVotes) {
        if (pollId >= polls.length) revert PollNotFound(pollId);
        Poll storage p = polls[pollId];
        return (p.votes, p.totalVotes);
    }

    function hasVotedOn(uint256 pollId, address voter) external view returns (bool) {
        if (pollId >= polls.length) revert PollNotFound(pollId);
        return hasVoted[pollId][voter];
    }

    function myVote(uint256 pollId, address voter) external view returns (bool voted, uint8 optionIndex) {
        if (pollId >= polls.length) revert PollNotFound(pollId);
        return (hasVoted[pollId][voter], voteOf[pollId][voter]);
    }
}

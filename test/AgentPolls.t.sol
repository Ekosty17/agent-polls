// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AgentPolls.sol";

/// Minimal stand-in for the SPACE ID Agent ID registry (ERC-721 balanceOf).
contract MockAgentId {
    mapping(address => uint256) public balances;

    function setBalance(address account, uint256 amount) external {
        balances[account] = amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}

contract AgentPollsTest is Test {
    AgentPolls public polls;
    MockAgentId public registry;

    address holder1 = address(0x1111);
    address holder2 = address(0x2222);
    address stranger = address(0x3333);

    string[] twoOptions;
    string[] sevenOptions;

    function setUp() public {
        registry = new MockAgentId();
        registry.setBalance(holder1, 1);
        registry.setBalance(holder2, 1);
        // stranger holds no Agent ID.
        polls = new AgentPolls(address(registry));

        twoOptions = new string[](2);
        twoOptions[0] = "Yes";
        twoOptions[1] = "No";

        sevenOptions = new string[](7);
        for (uint256 i = 0; i < 7; i++) sevenOptions[i] = "opt";
    }

    function testIsAgentIdHolder() public view {
        assertTrue(polls.isAgentIdHolder(holder1));
        assertFalse(polls.isAgentIdHolder(stranger));
    }

    function testCreatePoll() public {
        vm.prank(holder1);
        uint256 id = polls.createPoll("Should agents vote on-chain?", twoOptions, 7 days);
        assertEq(id, 0);
        assertEq(polls.pollCount(), 1);
        (address creator, string memory q, uint256 deadline, uint256 total, uint256 n) =
            polls.getPollMeta(0);
        assertEq(creator, holder1);
        assertEq(q, "Should agents vote on-chain?");
        assertEq(deadline, block.timestamp + 7 days);
        assertEq(total, 0);
        assertEq(n, 2);
        assertEq(polls.getOption(0, 0), "Yes");
        assertEq(polls.getOption(0, 1), "No");
    }

    function testCreatePollEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit AgentPolls.PollCreated(0, holder1, "Q?", block.timestamp + 1 days, 2);
        vm.prank(holder1);
        polls.createPoll("Q?", twoOptions, 1 days);
    }

    function testCreatePollNonHolderReverts() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(AgentPolls.NotAgentIdHolder.selector, stranger));
        polls.createPoll("Q?", twoOptions, 1 days);
    }

    function testCreatePollOneOptionReverts() public {
        string[] memory one = new string[](1);
        one[0] = "Only";
        vm.prank(holder1);
        vm.expectRevert(abi.encodeWithSelector(AgentPolls.InvalidOptionCount.selector, 1));
        polls.createPoll("Q?", one, 1 days);
    }

    function testCreatePollSevenOptionsReverts() public {
        vm.prank(holder1);
        vm.expectRevert(abi.encodeWithSelector(AgentPolls.InvalidOptionCount.selector, 7));
        polls.createPoll("Q?", sevenOptions, 1 days);
    }

    function testCreatePollEmptyQuestionReverts() public {
        vm.prank(holder1);
        vm.expectRevert(AgentPolls.EmptyQuestion.selector);
        polls.createPoll("", twoOptions, 1 days);
    }

    function testCreatePollEmptyOptionReverts() public {
        string[] memory opts = new string[](2);
        opts[0] = "Yes";
        opts[1] = "";
        vm.prank(holder1);
        vm.expectRevert(abi.encodeWithSelector(AgentPolls.EmptyOption.selector, 1));
        polls.createPoll("Q?", opts, 1 days);
    }

    function testCreatePollDurationTooShortReverts() public {
        vm.prank(holder1);
        vm.expectRevert(abi.encodeWithSelector(AgentPolls.InvalidDuration.selector, 30 minutes));
        polls.createPoll("Q?", twoOptions, 30 minutes);
    }

    function testCreatePollDurationTooLongReverts() public {
        vm.prank(holder1);
        vm.expectRevert(abi.encodeWithSelector(AgentPolls.InvalidDuration.selector, 91 days));
        polls.createPoll("Q?", twoOptions, 91 days);
    }

    function testVote() public {
        vm.prank(holder1);
        polls.createPoll("Q?", twoOptions, 1 days);
        vm.prank(holder1);
        polls.vote(0, 0);
        vm.prank(holder2);
        polls.vote(0, 1);
        (uint256[] memory votes, uint256 total) = polls.getResults(0);
        assertEq(votes[0], 1);
        assertEq(votes[1], 1);
        assertEq(total, 2);
        assertEq(polls.getOptionVotes(0, 0), 1);
        assertTrue(polls.hasVotedOn(0, holder1));
        (bool voted, uint8 choice) = polls.myVote(0, holder1);
        assertTrue(voted);
        assertEq(choice, 0);
    }

    function testVoteEmitsEvent() public {
        vm.prank(holder1);
        polls.createPoll("Q?", twoOptions, 1 days);
        vm.expectEmit(true, true, true, false);
        emit AgentPolls.VoteCast(0, holder1, 0);
        vm.prank(holder1);
        polls.vote(0, 0);
    }

    function testDoubleVoteReverts() public {
        vm.prank(holder1);
        polls.createPoll("Q?", twoOptions, 1 days);
        vm.prank(holder1);
        polls.vote(0, 0);
        vm.prank(holder1);
        vm.expectRevert(abi.encodeWithSelector(AgentPolls.AlreadyVoted.selector, 0, holder1));
        polls.vote(0, 1);
    }

    function testVoteNonHolderReverts() public {
        vm.prank(holder1);
        polls.createPoll("Q?", twoOptions, 1 days);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(AgentPolls.NotAgentIdHolder.selector, stranger));
        polls.vote(0, 0);
    }

    function testVoteAfterDeadlineReverts() public {
        vm.prank(holder1);
        polls.createPoll("Q?", twoOptions, 1 days);
        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(holder1);
        vm.expectRevert(abi.encodeWithSelector(AgentPolls.PollClosed.selector, 0));
        polls.vote(0, 0);
    }

    function testVoteAtDeadlineBoundaryReverts() public {
        vm.prank(holder1);
        polls.createPoll("Q?", twoOptions, 1 days);
        vm.warp(block.timestamp + 1 days);
        vm.prank(holder1);
        vm.expectRevert(abi.encodeWithSelector(AgentPolls.PollClosed.selector, 0));
        polls.vote(0, 0);
    }

    function testVoteInvalidOptionReverts() public {
        vm.prank(holder1);
        polls.createPoll("Q?", twoOptions, 1 days);
        vm.prank(holder1);
        vm.expectRevert(abi.encodeWithSelector(AgentPolls.InvalidOption.selector, 0, 2));
        polls.vote(0, 2);
    }

    function testVoteNonexistentPollReverts() public {
        vm.prank(holder1);
        vm.expectRevert(abi.encodeWithSelector(AgentPolls.PollNotFound.selector, 99));
        polls.vote(99, 0);
    }

    function testGetPollMetaNonexistentReverts() public {
        vm.expectRevert(abi.encodeWithSelector(AgentPolls.PollNotFound.selector, 5));
        polls.getPollMeta(5);
    }

    function testSixOptionsAllowed() public {
        string[] memory six = new string[](6);
        for (uint256 i = 0; i < 6; i++) six[i] = "opt";
        vm.prank(holder1);
        uint256 id = polls.createPoll("Pick one", six, 2 days);
        assertEq(id, 0);
        (, , , , uint256 n) = polls.getPollMeta(0);
        assertEq(n, 6);
    }

    function testSecondPollGetsNextId() public {
        vm.prank(holder1);
        polls.createPoll("First?", twoOptions, 1 days);
        vm.prank(holder2);
        uint256 id = polls.createPoll("Second?", twoOptions, 3 days);
        assertEq(id, 1);
        assertEq(polls.pollCount(), 2);
    }
}

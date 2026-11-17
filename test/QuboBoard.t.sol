// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/QuboBoard.sol";

contract QuboBoardTest is Test {
    QuboBoard board;
    address client = makeAddr("client");
    address solverA = makeAddr("solverA");
    address solverB = makeAddr("solverB");
    address stranger = makeAddr("stranger");

    bytes32 constant HASH_A = keccak256("assignment A");
    bytes32 constant HASH_B = keccak256("assignment B");

    function setUp() public {
        board = new QuboBoard();
        vm.deal(client, 100 ether);
        vm.deal(solverA, 1 ether);
        vm.deal(solverB, 1 ether);
    }

    function _postJob() internal returns (uint256 jobId) {
        vm.prank(client);
        jobId = board.postJob{value: 5 ether}(
            "Minimize 64-var QUBO", "ipfs://bafyqubo-instance-1", uint64(block.timestamp + 1 days)
        );
    }

    // ---- postJob ----

    function testPostJobCreatesJobWithEscrow() public {
        vm.prank(client);
        uint256 jobId = board.postJob{value: 5 ether}(
            "Minimize 64-var QUBO", "ipfs://bafyqubo-instance-1", uint64(block.timestamp + 1 days)
        );
        assertEq(jobId, 0);
        assertEq(board.jobCount(), 1);
        QuboBoard.Job memory job = board.getJob(jobId);
        assertEq(job.client, client);
        assertEq(job.title, "Minimize 64-var QUBO");
        assertEq(job.reward, 5 ether);
        assertEq(address(board).balance, 5 ether);
        assertFalse(job.accepted);
        assertFalse(job.cancelled);
    }

    function testPostJobZeroRewardReverts() public {
        vm.prank(client);
        vm.expectRevert(QuboBoard.ZeroReward.selector);
        board.postJob("t", "d", uint64(block.timestamp + 1 hours));
    }

    function testPostJobPastDeadlineReverts() public {
        vm.prank(client);
        vm.expectRevert(QuboBoard.DeadlineInPast.selector);
        board.postJob{value: 1 ether}("t", "d", uint64(block.timestamp));
    }

    function testPostJobIdsIncrement() public {
        _postJob();
        vm.prank(client);
        uint256 second = board.postJob{value: 1 ether}(
            "Second job", "ipfs://second", uint64(block.timestamp + 1 days)
        );
        assertEq(second, 1);
        assertEq(board.jobCount(), 2);
    }

    // ---- submitSolution ----

    function testSubmitSolutionRecordsIt() public {
        uint256 jobId = _postJob();
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, -1234);
        assertEq(board.solutionCount(jobId), 1);
        QuboBoard.Solution[] memory sols = board.getSolutions(jobId);
        assertEq(sols[0].solver, solverA);
        assertEq(sols[0].solutionHash, HASH_A);
        assertEq(sols[0].objective, -1234);
    }

    function testSubmitMultipleSolvers() public {
        uint256 jobId = _postJob();
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, -100);
        vm.prank(solverB);
        board.submitSolution(jobId, HASH_B, -200);
        assertEq(board.solutionCount(jobId), 2);
    }

    function testSubmitAfterDeadlineReverts() public {
        uint256 jobId = _postJob();
        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(solverA);
        vm.expectRevert(QuboBoard.DeadlinePassed.selector);
        board.submitSolution(jobId, HASH_A, -1);
    }

    function testSubmitByClientReverts() public {
        uint256 jobId = _postJob();
        vm.prank(client);
        vm.expectRevert(QuboBoard.IsClient.selector);
        board.submitSolution(jobId, HASH_A, -1);
    }

    function testSubmitDuplicateReverts() public {
        uint256 jobId = _postJob();
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, -100);
        vm.prank(solverA);
        vm.expectRevert(QuboBoard.AlreadySubmitted.selector);
        board.submitSolution(jobId, HASH_B, -200);
    }

    function testSubmitToMissingJobReverts() public {
        vm.prank(solverA);
        vm.expectRevert(QuboBoard.JobNotFound.selector);
        board.submitSolution(99, HASH_A, -1);
    }

    // ---- acceptSolution ----

    function testAcceptPaysSolver() public {
        uint256 jobId = _postJob();
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, -100);
        vm.prank(solverB);
        board.submitSolution(jobId, HASH_B, -200);

        uint256 before = solverB.balance;
        vm.prank(client);
        board.acceptSolution(jobId, solverB);
        assertEq(solverB.balance - before, 5 ether);
        assertEq(address(board).balance, 0);
        QuboBoard.Job memory job = board.getJob(jobId);
        assertTrue(job.accepted);
        assertEq(job.acceptedSolver, solverB);
        assertEq(job.reward, 0);
    }

    function testAcceptAfterDeadlineStillWorks() public {
        uint256 jobId = _postJob();
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, -100);
        vm.warp(block.timestamp + 1 days + 1); // submissions closed, client verifies late
        uint256 before = solverA.balance;
        vm.prank(client);
        board.acceptSolution(jobId, solverA);
        assertEq(solverA.balance - before, 5 ether);
    }

    function testAcceptByNonClientReverts() public {
        uint256 jobId = _postJob();
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, -100);
        vm.prank(stranger);
        vm.expectRevert(QuboBoard.NotClient.selector);
        board.acceptSolution(jobId, solverA);
    }

    function testAcceptUnknownSolverReverts() public {
        uint256 jobId = _postJob();
        vm.prank(client);
        vm.expectRevert(QuboBoard.SolverNotFound.selector);
        board.acceptSolution(jobId, solverA);
    }

    function testAcceptTwiceReverts() public {
        uint256 jobId = _postJob();
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, -100);
        vm.prank(client);
        board.acceptSolution(jobId, solverA);
        vm.prank(client);
        vm.expectRevert(QuboBoard.JobAlreadyAccepted.selector);
        board.acceptSolution(jobId, solverA);
    }

    function testSubmitToAcceptedJobReverts() public {
        uint256 jobId = _postJob();
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, -100);
        vm.prank(client);
        board.acceptSolution(jobId, solverA);
        vm.prank(solverB);
        vm.expectRevert(QuboBoard.JobAlreadyAccepted.selector);
        board.submitSolution(jobId, HASH_B, -200);
    }

    // ---- cancelJob ----

    function testCancelRefundsClient() public {
        uint256 jobId = _postJob();
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, -100);
        uint256 before = client.balance;
        vm.prank(client);
        board.cancelJob(jobId);
        assertEq(client.balance - before, 5 ether);
        assertEq(address(board).balance, 0);
        QuboBoard.Job memory job = board.getJob(jobId);
        assertTrue(job.cancelled);
        assertEq(job.reward, 0);
    }

    function testCancelByNonClientReverts() public {
        uint256 jobId = _postJob();
        vm.prank(stranger);
        vm.expectRevert(QuboBoard.NotClient.selector);
        board.cancelJob(jobId);
    }

    function testCancelAfterAcceptReverts() public {
        uint256 jobId = _postJob();
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, -100);
        vm.prank(client);
        board.acceptSolution(jobId, solverA);
        vm.prank(client);
        vm.expectRevert(QuboBoard.JobAlreadyAccepted.selector);
        board.cancelJob(jobId);
    }

    function testCancelTwiceReverts() public {
        uint256 jobId = _postJob();
        vm.prank(client);
        board.cancelJob(jobId);
        vm.prank(client);
        vm.expectRevert(QuboBoard.JobAlreadyCancelled.selector);
        board.cancelJob(jobId);
    }

    function testSubmitToCancelledJobReverts() public {
        uint256 jobId = _postJob();
        vm.prank(client);
        board.cancelJob(jobId);
        vm.prank(solverA);
        vm.expectRevert(QuboBoard.JobAlreadyCancelled.selector);
        board.submitSolution(jobId, HASH_A, -100);
    }

    // ---- fuzz ----

    function testFuzzObjectiveValue(int256 objective) public {
        uint256 jobId = _postJob();
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, objective);
        QuboBoard.Solution[] memory sols = board.getSolutions(jobId);
        assertEq(sols[0].objective, objective);
    }

    function testFuzzReward(uint96 rewardWei) public {
        vm.assume(rewardWei > 0 && rewardWei <= 10 ether);
        vm.prank(client);
        uint256 jobId = board.postJob{value: rewardWei}(
            "fuzz job", "ipfs://fuzz", uint64(block.timestamp + 1 days)
        );
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, 0);
        uint256 before = solverA.balance;
        vm.prank(client);
        board.acceptSolution(jobId, solverA);
        assertEq(solverA.balance - before, uint256(rewardWei));
    }

    // ---- audit additions: boundaries, missing jobs, escrow isolation ----

    function testSubmitAtExactDeadlineSucceeds() public {
        uint256 jobId = _postJob();
        vm.warp(block.timestamp + 1 days); // exactly the deadline
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, -1);
        assertEq(board.solutionCount(jobId), 1);
    }

    function testAcceptOnMissingJobReverts() public {
        vm.prank(client);
        vm.expectRevert(QuboBoard.JobNotFound.selector);
        board.acceptSolution(99, solverA);
    }

    function testCancelOnMissingJobReverts() public {
        vm.prank(client);
        vm.expectRevert(QuboBoard.JobNotFound.selector);
        board.cancelJob(99);
    }

    function testViewsOnMissingJobRevert() public {
        vm.expectRevert(QuboBoard.JobNotFound.selector);
        board.getJob(99);
        vm.expectRevert(QuboBoard.JobNotFound.selector);
        board.getSolutions(99);
        vm.expectRevert(QuboBoard.JobNotFound.selector);
        board.solutionCount(99);
    }

    function testAcceptClientAsSolverReverts() public {
        uint256 jobId = _postJob();
        vm.prank(client);
        vm.expectRevert(QuboBoard.SolverNotFound.selector);
        board.acceptSolution(jobId, client);
    }

    function testAcceptZeroAddressReverts() public {
        uint256 jobId = _postJob();
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, -1);
        vm.prank(client);
        vm.expectRevert(QuboBoard.SolverNotFound.selector);
        board.acceptSolution(jobId, address(0));
    }

    function testAcceptAfterCancelReverts() public {
        uint256 jobId = _postJob();
        vm.prank(solverA);
        board.submitSolution(jobId, HASH_A, -100);
        vm.prank(client);
        board.cancelJob(jobId);
        vm.prank(client);
        vm.expectRevert(QuboBoard.JobAlreadyCancelled.selector);
        board.acceptSolution(jobId, solverA);
    }

    function testTwoJobsEscrowIndependent() public {
        uint256 jobA = _postJob(); // 5 ether
        vm.prank(client);
        uint256 jobB = board.postJob{value: 3 ether}(
            "Second job", "ipfs://second", uint64(block.timestamp + 1 days)
        );
        assertEq(address(board).balance, 8 ether);
        vm.prank(solverA);
        board.submitSolution(jobA, HASH_A, -1);
        vm.prank(client);
        board.acceptSolution(jobA, solverA);
        // Job A paid out, job B untouched.
        assertEq(address(board).balance, 3 ether);
        QuboBoard.Job memory b = board.getJob(jobB);
        assertEq(b.reward, 3 ether);
        assertFalse(b.accepted);
        vm.prank(client);
        board.cancelJob(jobB);
        assertEq(address(board).balance, 0);
    }

    function testAcceptToRevertingReceiverFailsClosed() public {
        RevertingReceiver bad = new RevertingReceiver();
        uint256 jobId = _postJob();
        vm.prank(address(bad));
        board.submitSolution(jobId, HASH_A, -1);
        // The payout reverts, so the whole accept reverts: funds stay put
        // and the job is NOT marked accepted.
        vm.prank(client);
        vm.expectRevert(QuboBoard.TransferFailed.selector);
        board.acceptSolution(jobId, address(bad));
        assertEq(address(board).balance, 5 ether);
        assertFalse(board.getJob(jobId).accepted);
        // The client can still recover: cancel refunds the full escrow.
        uint256 before = client.balance;
        vm.prank(client);
        board.cancelJob(jobId);
        assertEq(client.balance - before, 5 ether);
    }

    function testAcceptToReentrantReceiverFailsClosed() public {
        ReentrantReceiver attacker = new ReentrantReceiver(board);
        uint256 jobId = _postJob();
        vm.prank(address(attacker));
        board.submitSolution(jobId, HASH_A, -1);
        // The attacker's receive() reenters acceptSolution; the inner call
        // reverts (wrong caller, and the job is already marked accepted),
        // so the receive reverts and the outer payout fails closed.
        // No funds move.
        vm.prank(client);
        vm.expectRevert(QuboBoard.TransferFailed.selector);
        board.acceptSolution(jobId, address(attacker));
        assertEq(address(board).balance, 5 ether);
        assertFalse(board.getJob(jobId).accepted);
        // A well-behaved solver can still be paid instead.
        vm.prank(solverB);
        board.submitSolution(jobId, HASH_B, -2);
        vm.prank(client);
        board.acceptSolution(jobId, solverB);
        assertEq(address(board).balance, 0);
    }
}

/// @notice A solver whose fallback always reverts: simulates a contract
/// solver that cannot receive QMS.
contract RevertingReceiver {
    receive() external payable {
        revert("no receive");
    }
}

/// @notice A solver that tries to reenter acceptSolution from its receive().
contract ReentrantReceiver {
    QuboBoard board;

    constructor(QuboBoard _board) {
        board = _board;
    }

    receive() external payable {
        // Reenter: this must fail because the job is already accepted.
        board.acceptSolution(0, address(this));
    }
}

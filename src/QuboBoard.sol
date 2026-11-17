// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title QuboBoard — a useful-work marketplace for QUBO optimization jobs on QMS.
/// @notice QMS miners solve QUBO (quadratic unconstrained binary optimization)
/// problems as proof-of-useful-work. QuboBoard turns that into a marketplace:
/// a client posts a job with a reward escrowed in QMS, solvers submit a hash
/// of their solution together with its objective value (lower is better for
/// QUBO minimization), and the client accepts one solution — the escrowed
/// reward is then paid to that solver on-chain. A job with no accepted
/// solution can be cancelled by its client for a full refund.
/// @dev No token, no custody beyond the per-job escrow held by this contract.
/// The full QUBO instance lives off-chain (details URI/CID); only the
/// solution hash and objective value are stored on-chain.
contract QuboBoard {
    struct Job {
        address client;
        string title;
        string details; // URI or CID of the full QUBO instance + rules
        uint256 reward; // wei escrowed (0 once paid out or refunded)
        uint64 deadline; // unix timestamp; submissions close at deadline
        bool accepted;
        bool cancelled;
        address acceptedSolver;
    }

    struct Solution {
        address solver;
        bytes32 solutionHash; // keccak256 of the full assignment vector
        int256 objective; // lower is better (QUBO minimization)
        uint64 submittedAt;
    }

    uint256 public jobCount;
    mapping(uint256 => Job) public jobs;
    mapping(uint256 => Solution[]) private _solutions;
    mapping(uint256 => mapping(address => bool)) private _hasSubmitted;

    event JobPosted(
        uint256 indexed jobId,
        address indexed client,
        string title,
        uint256 reward,
        uint64 deadline
    );
    event SolutionSubmitted(
        uint256 indexed jobId,
        address indexed solver,
        bytes32 solutionHash,
        int256 objective
    );
    event SolutionAccepted(
        uint256 indexed jobId,
        address indexed solver,
        uint256 reward
    );
    event JobCancelled(
        uint256 indexed jobId,
        address indexed client,
        uint256 refund
    );

    error ZeroReward();
    error DeadlineInPast();
    error JobNotFound();
    error JobAlreadyAccepted();
    error JobAlreadyCancelled();
    error NotClient();
    error IsClient();
    error AlreadySubmitted();
    error DeadlinePassed();
    error SolverNotFound();
    error TransferFailed();

    /// @notice Post a job, escrowing `msg.value` as the reward.
    /// @param title Short human-readable title.
    /// @param details URI/CID of the full QUBO instance and submission rules.
    /// @param deadline Unix timestamp after which no solutions are accepted.
    /// @return jobId The id of the newly created job.
    function postJob(string calldata title, string calldata details, uint64 deadline)
        external
        payable
        returns (uint256 jobId)
    {
        if (msg.value == 0) revert ZeroReward();
        // Deadlines are day-scale, so a few seconds of validator timestamp
        // skew cannot change any outcome.
        // forge-lint: disable-next-line(block-timestamp)
        if (deadline <= block.timestamp) revert DeadlineInPast();

        jobId = jobCount++;
        jobs[jobId] = Job({
            client: msg.sender,
            title: title,
            details: details,
            reward: msg.value,
            deadline: deadline,
            accepted: false,
            cancelled: false,
            acceptedSolver: address(0)
        });
        emit JobPosted(jobId, msg.sender, title, msg.value, deadline);
    }

    /// @notice Submit a solution to an open job. One submission per solver.
    /// @param jobId The job to solve.
    /// @param solutionHash keccak256 of the full assignment vector.
    /// @param objective Objective value of the solution (lower is better).
    function submitSolution(uint256 jobId, bytes32 solutionHash, int256 objective) external {
        Job storage job = jobs[jobId];
        if (job.client == address(0)) revert JobNotFound();
        if (job.accepted) revert JobAlreadyAccepted();
        if (job.cancelled) revert JobAlreadyCancelled();
        // Same day-scale deadline reasoning as postJob.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp > job.deadline) revert DeadlinePassed();
        if (msg.sender == job.client) revert IsClient();
        if (_hasSubmitted[jobId][msg.sender]) revert AlreadySubmitted();

        _hasSubmitted[jobId][msg.sender] = true;
        _solutions[jobId].push(
            Solution({
                solver: msg.sender,
                solutionHash: solutionHash,
                objective: objective,
                // Casting to uint64 is safe because block.timestamp fits in
                // uint64 for ~584 billion years.
                // forge-lint: disable-next-line(unsafe-typecast)
                submittedAt: uint64(block.timestamp)
            })
        );
        emit SolutionSubmitted(jobId, msg.sender, solutionHash, objective);
    }

    /// @notice Accept a solver's solution and pay them the escrowed reward.
    /// @dev Acceptance has no deadline: the client may take time to verify a
    /// solution off-chain after submissions close. State is updated before
    /// the transfer (checks-effects-interactions).
    /// @param jobId The job whose solution is accepted.
    /// @param solver The solver to pay.
    function acceptSolution(uint256 jobId, address solver) external {
        Job storage job = jobs[jobId];
        if (job.client == address(0)) revert JobNotFound();
        if (msg.sender != job.client) revert NotClient();
        if (job.accepted) revert JobAlreadyAccepted();
        if (job.cancelled) revert JobAlreadyCancelled();
        if (solver == address(0)) revert SolverNotFound();
        if (!_hasSubmitted[jobId][solver]) revert SolverNotFound();

        uint256 reward = job.reward;
        job.accepted = true;
        job.acceptedSolver = solver;
        job.reward = 0;
        emit SolutionAccepted(jobId, solver, reward);

        // The payout destination is always a solver who actually submitted
        // to this job (checked above), and all state is zeroed before the
        // transfer (checks-effects-interactions), so a reentrant receiver
        // cannot drain anything — its inner call reverts and the outer
        // transfer fails closed instead.
        // forge-lint: disable-next-line(arbitrary-send-eth)
        (bool ok,) = solver.call{value: reward}("");
        if (!ok) revert TransferFailed();
    }

    /// @notice Cancel an open job and refund the full escrowed reward.
    /// @param jobId The job to cancel.
    function cancelJob(uint256 jobId) external {
        Job storage job = jobs[jobId];
        if (job.client == address(0)) revert JobNotFound();
        if (msg.sender != job.client) revert NotClient();
        if (job.accepted) revert JobAlreadyAccepted();
        if (job.cancelled) revert JobAlreadyCancelled();

        uint256 refund = job.reward;
        job.cancelled = true;
        job.reward = 0;
        emit JobCancelled(jobId, msg.sender, refund);

        (bool ok,) = msg.sender.call{value: refund}("");
        if (!ok) revert TransferFailed();
    }

    /// @notice Read a job's full record.
    function getJob(uint256 jobId) external view returns (Job memory) {
        if (jobs[jobId].client == address(0)) revert JobNotFound();
        return jobs[jobId];
    }

    /// @notice Read all solutions submitted to a job, in submission order.
    function getSolutions(uint256 jobId) external view returns (Solution[] memory) {
        if (jobs[jobId].client == address(0)) revert JobNotFound();
        return _solutions[jobId];
    }

    /// @notice Number of solutions submitted to a job.
    function solutionCount(uint256 jobId) external view returns (uint256) {
        if (jobs[jobId].client == address(0)) revert JobNotFound();
        return _solutions[jobId].length;
    }
}

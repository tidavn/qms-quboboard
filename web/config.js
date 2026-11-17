// QuboBoard deployment config.
// CONTRACT_ADDRESS is filled in after deployment. If it is still the zero
// address, the app shows a notice instead of trying to talk to the chain.
const CONFIG = {
  CONTRACT_ADDRESS: "0xcaf57e3c105ecc1452702cc5b77a167a031c2f5d", // QuboBoard on QMS Testnet, verified on Blockscout
  CHAIN_ID: 19480,
  CHAIN_ID_HEX: "0x4c18",
  CHAIN_NAME: "QMS Testnet",
  RPC_URL: "https://rpc.testnet.qms.finance",
  EXPLORER_URL: "https://testnet.qmsscan.io",
  FAUCET_URL: "https://faucet.testnet.qms.finance",
  CURRENCY: "QMS",
};

// Minimal ABI of QuboBoard (see contracts/src/QuboBoard.sol).
const QUBOBOARD_ABI = [
  "function jobCount() view returns (uint256)",
  "function getJob(uint256 jobId) view returns (tuple(address client, string title, string details, uint256 reward, uint64 deadline, bool accepted, bool cancelled, address acceptedSolver))",
  "function getSolutions(uint256 jobId) view returns (tuple(address solver, bytes32 solutionHash, int256 objective, uint64 submittedAt)[])",
  "function solutionCount(uint256 jobId) view returns (uint256)",
  "function postJob(string title, string details, uint64 deadline) payable returns (uint256)",
  "function submitSolution(uint256 jobId, bytes32 solutionHash, int256 objective)",
  "function acceptSolution(uint256 jobId, address solver)",
  "function cancelJob(uint256 jobId)",
  "event JobPosted(uint256 indexed jobId, address indexed client, string title, uint256 reward, uint64 deadline)",
  "event SolutionSubmitted(uint256 indexed jobId, address indexed solver, bytes32 solutionHash, int256 objective)",
  "event SolutionAccepted(uint256 indexed jobId, address indexed solver, uint256 reward)",
  "event JobCancelled(uint256 indexed jobId, address indexed client, uint256 refund)",
  // Custom errors, so ethers decodes reverts by name instead of raw data.
  "error ZeroReward()",
  "error DeadlineInPast()",
  "error JobNotFound()",
  "error JobAlreadyAccepted()",
  "error JobAlreadyCancelled()",
  "error NotClient()",
  "error IsClient()",
  "error AlreadySubmitted()",
  "error DeadlinePassed()",
  "error SolverNotFound()",
  "error TransferFailed()",
];

# QuboBoard — a useful-work marketplace on QMS Testnet

QMS miners solve QUBO (quadratic unconstrained binary optimization) problems
as proof-of-useful-work. **QuboBoard turns that into a marketplace**: a client
posts an optimization job with a reward escrowed in QMS, solvers submit a hash
of their solution together with its objective value (lower is better for QUBO
minimization), and the client accepts one solution — the escrowed reward is
then paid to that solver on-chain. A job with no accepted solution can be
cancelled by its client for a full refund.

Built for the **QMS Builder Program, Cohort 1** (applications close
2026-11-18 13:00 UTC).

## Live deployment (QMS Testnet, chain 19480)

- Contract: **0xcaf57e3c105ecc1452702cc5b77a167a031c2f5d** — deployed
  2026-11-17, tx
  0xa0cb675fd4d5ac3abdbd965f9d1a6d0c10a037707315c9b5f47cfaed361d821e,
  verified on Blockscout (Pass - Verified, solc 0.8.28)
- Explorer: https://testnet.qmsscan.io
- Faucet: https://faucet.testnet.qms.finance (test QMS per request, max 4 requests per 24h — the faucet page shows the current amount)
- Demo frontend: `web/index.html` (static site, no build step)

> Status 2026-11-17: contract deployed and verified on QMS Testnet
> (0xcaf57e3c105ecc1452702cc5b77a167a031c2f5d). Live end-to-end smoke test
> passed on-chain: job posted (0.01 QMS escrow), solution submitted,
> accepted and paid exactly (solver 0.05 → ~0.06 QMS), job marked accepted.
> See the explorer link above.

## Why QMS

QMS is the only chain whose block production *is* optimization work: every
block shows the QUBO instance that was solved, the winning solution and its
objective value. QuboBoard is the commercial layer on top of that — it gives
real clients a way to pay for solutions and real solvers a way to earn, using
exactly the workload QMS miners already run. No other EVM chain has this
native fit: on any other chain the "useful work" would be simulated; on QMS
it is the consensus itself.

## 90-day plan

- **Days 0–30 (testnet polish):** Deploy + verify; seed the board with 5–10
  real QUBO jobs taken from public QMS block data (instances published in the
  explorer, `.mtx.gz` downloads); dogfood with community solvers; add an
  off-chain verifier that checks a revealed assignment against the posted
  instance before the client accepts.
- **Days 30–60 (first real users):** Onboard 2–3 small teams who already run
  optimization workloads (logistics, scheduling, portfolio) to post paid
  jobs; publish a leaderboard of solvers by accepted solutions and objective
  improvement; write a public post-mortem of the first paid jobs (what
  cleared, what didn't, what the contract should change).
- **Days 60–90 (mainnet-ready):** Audit pass on the contract (external review
  if the program supports it), gas and UX hardening from testnet usage, and a
  mainnet deployment plan ready to execute when QMS mainnet opens — same
  contract, same frontend, pointed at mainnet.

**Success metrics for 90 days:** 25+ jobs posted, 10+ paid solutions,
3+ returning clients, 1 external audit/review, contract unchanged on mainnet
except for audit findings.

**Known limitation:** the client is fully trusted — they can cancel a job
after solvers have submitted and reclaim the whole reward, so submitted work
can go unpaid. No dispute mechanism, partial payment, or solver reputation
yet; a commit-reveal + time-locked acceptance window is the first item in the
Days 0–30 plan above.

## Contract

Single contract, no token, no custody beyond the per-job escrow:

| Function | What it does |
| --- | --- |
| `postJob(title, details, deadline)` payable | Post a job, escrow `msg.value` as the reward |
| `submitSolution(jobId, solutionHash, objective)` | Submit a solution hash + objective (one per solver) |
| `acceptSolution(jobId, solver)` | Accept a solution, pay the escrowed reward to the solver |
| `cancelJob(jobId)` | Cancel an open job, full refund to the client |
| `getJob / getSolutions / solutionCount / jobCount` | Read-only views |

Rules: reward must be > 0; deadline must be in the future; submissions close
at the deadline; the client cannot solve their own job; acceptance has no
deadline (the client may verify a solution off-chain first); state is updated
before every transfer (checks-effects-interactions).

## Run it locally

```bash
# install dependencies (forge-std is not vendored in the repo)
forge install

# tests
forge test

# deploy to QMS Testnet (needs a funded throwaway key in .env)
source .env   # PRIVATE_KEY=0x...
forge script script/Deploy.s.sol --rpc-url qms_testnet --broadcast

# verify on Blockscout (no API key needed)
forge verify-contract --verifier blockscout \
  --verifier-url https://testnet.qmsscan.io/api \
  <ADDRESS> src/QuboBoard.sol:QuboBoard
```

Then put the deployed address in `web/config.js` (`CONTRACT_ADDRESS`) and
serve `web/` with any static host (or open `index.html` directly).

## Frontend

`web/` is a static site (ethers v6 via CDN, no build step):

- Connect wallet (MetaMask), auto-offers adding/switching to QMS Testnet
  (chain 19480, `0x4c18`).
- Lists jobs from the contract, newest first, with solutions and the best
  objective so far.
- Post a job (reward escrowed), submit a solution (your assignment is hashed
  with keccak256 in-browser — only the hash + objective go on-chain),
  accept a solution (client only), cancel a job (client only, full refund).

## Project layout

```
src/QuboBoard.sol      the contract
test/QuboBoard.t.sol   33 Foundry tests (incl. 2 fuzz tests, reentrancy and reverting-receiver cases)
script/Deploy.s.sol    deployment script
web/                   static frontend (index.html, app.js, config.js)
APPLICATION-DRAFT.md   the Builder Program application, ready to paste
```

## Links

- QMS docs (developers): https://docs.qms.finance/for-developers/
- Network & RPC: https://docs.qms.finance/for-developers/network-and-rpc/
- QMS Testnet explorer: https://testnet.qmsscan.io
- Builder Program: https://qms.finance/builders-program

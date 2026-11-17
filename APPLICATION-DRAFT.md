# QMS Builder Program — Application Draft (Cohort 1)

> Paste-ready answers for the REAL form at
> https://qms.finance/builders-program/apply
> (checked in full 2026-11-17: 4 steps, no login, no wallet, no file upload;
> response within 10 working days; NO confirmation email is issued).
> Applications close 2026-11-18 13:00 UTC / 20:00 +07.
> Fields marked **[TO FILL BY NGUYEN]** are your own identity — fill them in
> yourself, do not invent them. Character limits are the form's own limits;
> every answer below was counted to fit.
> The form has NO dedicated field for a 90-day plan or "why QMS" — the
> 90-day plan lives in README.md (linked from Step 2 as the repo).

## Step 1 — You & your team

- **Name or nickname*:** Dat Nguyen
- **Email*:** tida.eth@gmail.com
- **Discord handle* (max 32):** tida.eth
- **X handle*:** @d94zETH

**Founder 01**
- Name* (max 50): Dat Nguyen
- Role* (max 30): Founder & developer
- Link* (max 120, incl. https://): https://x.com/d94zETH

**Relevant experience and past projects* (max 400):**
Solo builder shipping on QMS Testnet: QuboBoard (Solidity + Foundry, 33
passing tests incl. fuzz + reentrancy cases, verified on Blockscout) and
several AI-agent-built web apps on GitHub as tidavn. Full stack: contracts,
tests, frontend, deployment.

**Are the founders publicly identifiable?*** Partially — GitHub profile
(tidavn) and shipped public repos are public; legal name shared privately
with the QMS team on request.

## Step 2 — Your project

- **Project name*:** QuboBoard
- **Website* (https://):** https://github.com/tidavn/qms-quboboard
  (repo; replace with the demo URL once the frontend is hosted)
- **One-line description* (max 140):**
  A marketplace for useful work on QMS: post QUBO jobs with escrowed rewards,
  solvers submit solutions and get paid on-chain.
- **Category*:** Others — specify (max 50): Compute marketplace
- **Stage*:** TESTNET (contract deployed + verified — see below)

**What are you building on QMS, and who will use it?* (max 550):**
QMS miners solve QUBO optimization problems as proof-of-useful-work; every
block publishes the instance, winning solution and objective value. QuboBoard
is the commercial layer: a client posts a job and escrows a QMS reward,
solvers submit a solution hash + objective value (lower is better), the client
accepts one and the reward is paid on-chain. Users: teams with optimization
workloads (logistics, scheduling, portfolio) and QMS solvers/miners.

**How will it sustain itself or make money?* (max 300):**
No token and no fees at launch — the goal is usage first. Later: a small
protocol fee on accepted jobs (e.g. 2-5%) once real volume exists, plus paid
support for teams posting jobs.

**Shipping evidence (links — paste the repo + contract into Website above;
the form has no separate links field, so put the contract in Step 3's
measurement link and the plan in the README):**
- Repo: https://github.com/tidavn/qms-quboboard
- Contract (QMS Testnet, verified on Blockscout): 0xcaf57e3c105ecc1452702cc5b77a167a031c2f5d
- Explorer: https://testnet.qmsscan.io/address/0xcaf57e3c105ecc1452702cc5b77a167a031c2f5d
- Deploy tx: 0xa0cb675fd4d5ac3abdbd965f9d1a6d0c10a037707315c9b5f47cfaed361d821e
- Live smoke test on-chain: job posted (0.01 QMS escrow), solution submitted,
  accepted and paid exactly; job marked accepted.
- Demo frontend: [DEMO URL — TO FILL AFTER HOSTING, or run web/index.html locally]
- Tests: 33/33 Foundry tests pass (post/submit/accept/cancel flows, access
  control, deadline reverts, payout math, 2 fuzz tests, reentrancy and
  reverting-receiver cases) — `forge test` in the repo. `forge build` is
  warning-free.

## Step 3 — Traction & funding

**USERS**
- **Active users in the last 30 days*:** 0
  (honest: brand-new project, no users yet — testnet users count)
- **How is that measured?* (link, max 150 incl. https://):**
  https://testnet.qmsscan.io/address/0xcaf57e3c105ecc1452702cc5b77a167a031c2f5d
  (contract activity on the QMS explorer; no users yet, so no dashboard)

**COMMUNITY (up to 3 public channels)**
- **Channel 1 URL* (max 120 incl. https://):**
  https://x.com/d94zETH
- **Followers / members*:** [TO FILL BY NGUYEN — số follower X của bạn]

**FUNDING (optional — can be left blank)**
- Funding status: Not raised
- Backers or investors: (blank)

## Step 4 — Support & submit

**What support would help most?* (max 500):**
Technical review of the contract and solver-verification design (next step:
on-chain verification of a revealed solution against the posted instance),
plus visibility in the "Built on QMS" showcase once the first real jobs are
posted. No funding requested at this stage.

**Known limitation (state it in the builder channel, not hidden):** the client
is fully trusted — they can cancel a job after solvers have submitted and
reclaim the whole reward, so submitted work can go unpaid. No dispute
mechanism, partial payment, or solver reputation yet; a commit-reveal +
time-locked acceptance window is the first item in the 90-day plan (README).

**Confirm & submit:** tick the terms checkbox yourself and pass the
Cloudflare Turnstile check, then click SUBMIT APPLICATION. No confirmation
email is issued — the team replies within 10 working days.

---

### 90-day plan (lives in README.md — the form has no field for it)

- **Days 0–30 (testnet polish):** Deploy + verify (done at application time);
  seed the board with 5–10 real QUBO jobs taken from public QMS block data
  (instances published in the explorer, `.mtx.gz` downloads); dogfood with
  community solvers; add an off-chain verifier that checks a revealed
  assignment against the posted instance before the client accepts.
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

---

### Checklist before submitting (for Nguyen)

- [x] Fill in name / email / Discord / X above (done 2026-11-17).
- [x] Deploy the contract + verify it (done 2026-11-17: 0xcaf57e3c105ecc1452702cc5b77a167a031c2f5d, verified, live smoke test passed).
- [ ] Host the `web/` demo (any static host) and paste the URL as Website.
- [ ] Fill in X follower count (Step 3).
- [ ] Submit at https://qms.finance/builders-program/apply before
      2026-11-18 13:00 UTC (20:00 +07). Tick the terms box + Turnstile
      yourself and click SUBMIT APPLICATION.

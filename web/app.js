/* QuboBoard frontend — static, ethers v6, no build step. */
"use strict";

const $ = (id) => document.getElementById(id);
const ZERO = "0x0000000000000000000000000000000000000000";

let provider = null; // ethers.BrowserProvider
let signer = null;
let contract = null; // read/write QuboBoard
let account = null;

function setStatus(msg, isError) {
  const el = $("status");
  el.textContent = msg || "";
  el.style.color = isError ? "var(--bad)" : "";
}

function explorerTx(hash) {
  return `${CONFIG.EXPLORER_URL}/tx/${hash}`;
}

function shortAddr(a) {
  return a ? a.slice(0, 6) + "…" + a.slice(-4) : "";
}

async function ensureChain() {
  const chainId = await window.ethereum.request({ method: "eth_chainId" });
  if (chainId.toLowerCase() !== CONFIG.CHAIN_ID_HEX) {
    try {
      await window.ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: CONFIG.CHAIN_ID_HEX }],
      });
    } catch (e) {
      if (e && e.code === 4902) await addChain();
      else throw e;
    }
    // Adding a chain does not always switch to it: verify, don't assume.
    const after = await window.ethereum.request({ method: "eth_chainId" });
    if (after.toLowerCase() !== CONFIG.CHAIN_ID_HEX) {
      throw new Error("Please switch your wallet to QMS Testnet (chain 19480).");
    }
  }
}

async function addChain() {
  await window.ethereum.request({
    method: "wallet_addEthereumChain",
    params: [{
      chainId: CONFIG.CHAIN_ID_HEX,
      chainName: CONFIG.CHAIN_NAME,
      rpcUrls: [CONFIG.RPC_URL],
      blockExplorerUrls: [CONFIG.EXPLORER_URL],
      nativeCurrency: { name: "QMS", symbol: CONFIG.CURRENCY, decimals: 18 },
    }],
  });
}

async function connect() {
  if (!window.ethereum) {
    setStatus("No wallet found. Install MetaMask (or any EVM wallet) and reload.", true);
    return;
  }
  try {
    provider = new ethers.BrowserProvider(window.ethereum);
    await provider.send("eth_requestAccounts", []);
    await ensureChain();
    signer = await provider.getSigner();
    account = await signer.getAddress();
    $("account").textContent = "Connected: " + shortAddr(account);
    contract = new ethers.Contract(CONFIG.CONTRACT_ADDRESS, QUBOBOARD_ABI, signer);
    setStatus("Connected on QMS Testnet.");
    await loadJobs();
  } catch (e) {
    setStatus("Connect failed: " + (e && e.message ? e.message : e), true);
  }
}

function readContract() {
  if (contract) return contract;
  const rpc = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
  return new ethers.Contract(CONFIG.CONTRACT_ADDRESS, QUBOBOARD_ABI, rpc);
}

function jobStatus(job) {
  if (job.accepted) return ["done", "Accepted"];
  if (job.cancelled) return ["dead", "Cancelled"];
  if (Date.now() / 1000 > Number(job.deadline)) return ["dead", "Deadline passed"];
  return ["open", "Open"];
}

function fmtQMS(wei) {
  return ethers.formatEther(wei) + " QMS";
}

function fmtDate(ts) {
  return new Date(Number(ts) * 1000).toLocaleString();
}

async function loadJobs() {
  const jobsEl = $("jobs");
  if (CONFIG.CONTRACT_ADDRESS === ZERO) {
    jobsEl.innerHTML = "<p class=\"muted\">No contract deployed yet — jobs will appear once the contract address is set in web/config.js.</p>";
    $("jobCount").textContent = "";
    return;
  }
  jobsEl.innerHTML = "<p class=\"muted\">Loading jobs…</p>";
  try {
    const c = readContract();
    const count = Number(await c.jobCount());
    $("jobCount").textContent = count + (count === 1 ? " job" : " jobs");
    if (count === 0) {
      jobsEl.innerHTML = "<p class=\"muted\">No jobs yet. Post the first one above.</p>";
      return;
    }
    jobsEl.innerHTML = "";
    for (let id = count - 1; id >= 0; id--) {
      const job = await c.getJob(id);
      const sols = await c.getSolutions(id);
      const [cls, label] = jobStatus(job);
      const div = document.createElement("div");
      div.className = "card job";
      const isClient = account && account.toLowerCase() === job.client.toLowerCase();
      const best = sols.length
        ? sols.reduce((a, b) => (a.objective < b.objective ? a : b))
        : null;
      div.innerHTML =
        `<h3>#${id} — ${escapeHtml(job.title)}</h3>` +
        `<p><span class="pill ${cls}">${label}</span> ` +
        `<span class="muted">Reward <b>${fmtQMS(job.reward)}</b> · ` +
        `Deadline ${fmtDate(job.deadline)} · Client <span class="mono">${shortAddr(job.client)}</span>` +
        (job.accepted ? ` · Accepted solver <span class="mono">${shortAddr(job.acceptedSolver)}</span>` : "") +
        `</span></p>` +
        `<p class="mono muted">Details: ${escapeHtml(job.details)}</p>` +
        `<p class="muted">${sols.length} solution(s)` +
        (best ? ` · best objective so far: <b>${best.objective.toString()}</b> by <span class="mono">${shortAddr(best.solver)}</span>` : "") +
        `</p>` +
        sols.map((s) =>
          `<div class="sol"><span class="mono">${shortAddr(s.solver)}</span> · objective <b>${s.objective.toString()}</b> · ` +
          `<span class="mono">${s.solutionHash.slice(0, 18)}…</span> · ${fmtDate(s.submittedAt)}` +
          (isClient && !job.accepted && !job.cancelled
            ? ` <button data-accept="${id}:${s.solver}">Accept &amp; pay</button>` : "") +
          `</div>`).join("") +
        (isClient && !job.accepted && !job.cancelled
          ? `<p><button data-cancel="${id}" class="ghost">Cancel job (refund)</button></p>` : "");
      jobsEl.appendChild(div);
    }
    jobsEl.querySelectorAll("[data-accept]").forEach((b) => {
      b.addEventListener("click", async () => {
        const [jobId, solver] = b.dataset.accept.split(":");
        await acceptSolution(Number(jobId), solver);
      });
    });
    jobsEl.querySelectorAll("[data-cancel]").forEach((b) => {
      b.addEventListener("click", async () => {
        await cancelJob(Number(b.dataset.cancel));
      });
    });
  } catch (e) {
    jobsEl.innerHTML = "";
    setStatus("Could not load jobs: " + (e && e.message ? e.message : e), true);
  }
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[c]);
}

async function postJob() {
  if (!contract) { setStatus("Connect your wallet first.", true); return; }
  const title = $("jobTitle").value.trim();
  const details = $("jobDetails").value.trim();
  const reward = $("jobReward").value.trim();
  const days = Number($("jobDays").value);
  if (!title || !details || !reward || !(days > 0)) {
    setStatus("Fill in title, details, reward and a deadline of at least 1 day.", true);
    return;
  }
  try {
    setStatus("Posting job… confirm in your wallet.");
    const deadline = Math.floor(Date.now() / 1000) + days * 86400;
    const tx = await contract.postJob(title, details, deadline, {
      value: ethers.parseEther(reward),
    });
    setStatus("Transaction sent: " + explorerTx(tx.hash));
    await tx.wait(1);
    setStatus("Job posted. " + explorerTx(tx.hash));
    await loadJobs();
  } catch (e) {
    setStatus("Post failed: " + (e && e.message ? e.message : e), true);
  }
}

async function submitSolution() {
  if (!contract) { setStatus("Connect your wallet first.", true); return; }
  const jobId = Number($("solJobId").value);
  const text = $("solText").value;
  const objective = $("solObjective").value.trim();
  if (!Number.isInteger(jobId) || jobId < 0 || !text || objective === "") {
    setStatus("Fill in job ID, your assignment text and the objective value.", true);
    return;
  }
  try {
    setStatus("Submitting solution… confirm in your wallet.");
    const hash = ethers.keccak256(ethers.toUtf8Bytes(text));
    const tx = await contract.submitSolution(jobId, hash, BigInt(objective));
    setStatus("Transaction sent: " + explorerTx(tx.hash));
    await tx.wait(1);
    setStatus("Solution submitted (hash " + hash.slice(0, 18) + "…). " + explorerTx(tx.hash));
    await loadJobs();
  } catch (e) {
    setStatus("Submit failed: " + (e && e.message ? e.message : e), true);
  }
}

async function acceptSolution(jobId, solver) {
  if (!contract) return;
  try {
    setStatus("Accepting solution… confirm in your wallet.");
    const tx = await contract.acceptSolution(jobId, solver);
    setStatus("Transaction sent: " + explorerTx(tx.hash));
    await tx.wait(1);
    setStatus("Solution accepted — reward paid to " + shortAddr(solver) + ". " + explorerTx(tx.hash));
    await loadJobs();
  } catch (e) {
    setStatus("Accept failed: " + (e && e.message ? e.message : e), true);
  }
}

async function cancelJob(jobId) {
  if (!contract) return;
  if (!confirm("Cancel job #" + jobId + " and refund the reward to yourself?")) return;
  try {
    setStatus("Cancelling job… confirm in your wallet.");
    const tx = await contract.cancelJob(jobId);
    setStatus("Transaction sent: " + explorerTx(tx.hash));
    await tx.wait(1);
    setStatus("Job cancelled, reward refunded. " + explorerTx(tx.hash));
    await loadJobs();
  } catch (e) {
    setStatus("Cancel failed: " + (e && e.message ? e.message : e), true);
  }
}

// ---- boot ----
$("contractAddr").textContent = CONFIG.CONTRACT_ADDRESS;
$("contractLink").href = CONFIG.EXPLORER_URL + "/address/" + CONFIG.CONTRACT_ADDRESS;
$("faucetLink").href = CONFIG.FAUCET_URL;
$("connectBtn").addEventListener("click", connect);
$("addChainBtn").addEventListener("click", async () => {
  if (!window.ethereum) { setStatus("No wallet found.", true); return; }
  try { await addChain(); setStatus("QMS Testnet added to your wallet."); }
  catch (e) { setStatus("Add chain failed: " + (e && e.message ? e.message : e), true); }
});
$("postBtn").addEventListener("click", postJob);
$("submitSolBtn").addEventListener("click", submitSolution);
$("refreshBtn").addEventListener("click", loadJobs);
if (window.ethereum) {
  window.ethereum.on("accountsChanged", () => location.reload());
  window.ethereum.on("chainChanged", () => location.reload());
}
if (CONFIG.CONTRACT_ADDRESS === ZERO) {
  $("notDeployed").classList.remove("hidden");
  setStatus("Contract not deployed yet — showing the page without on-chain data.");
} else {
  loadJobs();
}

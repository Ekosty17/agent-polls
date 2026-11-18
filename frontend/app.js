// Agent Polls frontend — plain JavaScript, no libraries, no build step.
// Reads go to the public BSC RPC (no wallet needed). Writes go through the
// user's own wallet (window.ethereum) and ALWAYS ask for confirmation.
// No QR-code login, no keys, no backend, no name lookups of other people.

'use strict';

// ---- Config: fill in after mainnet deployment ----
const CONTRACT_ADDRESS = '0x0000000000000000000000000000000000000000'; // TODO: deployed AgentPolls address
const AGENT_ID_REGISTRY = '0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F';
const RPC_URL = 'https://bsc-dataseed.binance.org';
const CHAIN_ID_HEX = '0x38'; // BNB Chain mainnet, 56
const BSCSCAN_TX = 'https://bscscan.com/tx/';

// Function selectors (first 4 bytes of keccak256 of the signature).
const SEL = {
  createPoll: 'f8c860f4',
  vote: '943e8216',
  getPollMeta: '8caa1354',
  getOption: '1ce30927',
  getOptionVotes: 'e7ea088f',
  pollCount: '9207891d',
  isAgentIdHolder: 'da0c34b0',
  balanceOf: '70a08231',
  hasVotedOn: 'b97d3e40',
};

// ---- Pure ABI helpers (also unit-tested from Node; see test-frontend-abi.js) ----
function toHex(n, bytes) {
  return BigInt(n).toString(16).padStart((bytes || 32) * 2, '0');
}
function addrWord(a) {
  return '0'.repeat(24) + String(a).toLowerCase().replace(/^0x/, '');
}
function encString(s) {
  const bytes = new TextEncoder().encode(s);
  const data = Array.from(bytes).map(function (b) { return b.toString(16).padStart(2, '0'); }).join('');
  const padded = data + '0'.repeat(((32 - (bytes.length % 32)) % 32) * 2);
  return toHex(bytes.length) + padded;
}
function encStringArray(arr) {
  let head = toHex(arr.length);
  let offset = 32 * arr.length;
  let tails = '';
  for (const s of arr) {
    head += toHex(offset);
    const e = encString(s);
    tails += e;
    offset += e.length / 2;
  }
  return head + tails;
}
function createPollData(question, options, durationSec) {
  const qEnc = encString(question);
  const oEnc = encStringArray(options);
  const headSize = 96; // 3 head words
  const offQ = headSize;
  const offO = headSize + qEnc.length / 2;
  return '0x' + SEL.createPoll + toHex(offQ) + toHex(offO) + toHex(durationSec) + qEnc + oEnc;
}
function voteData(pollId, optionIndex) {
  return '0x' + SEL.vote + toHex(pollId) + toHex(optionIndex);
}
function getPollMetaData(pollId) { return '0x' + SEL.getPollMeta + toHex(pollId); }
function getOptionData(pollId, i) { return '0x' + SEL.getOption + toHex(pollId) + toHex(i); }
function getOptionVotesData(pollId, i) { return '0x' + SEL.getOptionVotes + toHex(pollId) + toHex(i); }
function pollCountData() { return '0x' + SEL.pollCount; }
function isAgentIdHolderData(account) { return '0x' + SEL.isAgentIdHolder + addrWord(account); }
function hasVotedOnData(pollId, account) { return '0x' + SEL.hasVotedOn + toHex(pollId) + addrWord(account); }

function decUint(hex, byteOffset) {
  const h = String(hex).replace(/^0x/, '');
  return BigInt('0x' + h.slice(byteOffset * 2, byteOffset * 2 + 64));
}
function decAddress(hex, byteOffset) {
  const h = String(hex).replace(/^0x/, '');
  return '0x' + h.slice(byteOffset * 2 + 24, byteOffset * 2 + 64);
}
function decBool(hex, byteOffset) { return decUint(hex, byteOffset) !== 0n; }
function decStringAt(hex, wordPos) {
  const h = String(hex).replace(/^0x/, '');
  const off = Number(decUint(hex, wordPos));
  const len = Number(decUint(hex, off));
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = parseInt(h.slice((off + 32 + i) * 2, (off + 32 + i) * 2 + 2), 16);
  }
  return new TextDecoder().decode(bytes);
}
// getPollMeta returns (address creator, string question, uint256 deadline, uint256 totalVotes, uint256 optionCount)
function decPollMeta(hex) {
  return {
    creator: decAddress(hex, 0),
    question: decStringAt(hex, 32),
    deadline: Number(decUint(hex, 64)),
    totalVotes: Number(decUint(hex, 96)),
    optionCount: Number(decUint(hex, 128)),
  };
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    createPollData, voteData, getPollMetaData, getOptionData, getOptionVotesData,
    pollCountData, isAgentIdHolderData, hasVotedOnData,
    decUint, decAddress, decBool, decStringAt, decPollMeta, encString, encStringArray,
  };
}

// ---- Browser-only code below ----
if (typeof document !== 'undefined') {
  const $ = function (id) { return document.getElementById(id); };
  let account = null;
  let isHolder = false;

  function isDeployed() {
    return /^0x[0-9a-fA-F]{40}$/.test(CONTRACT_ADDRESS) && CONTRACT_ADDRESS !== '0x0000000000000000000000000000000000000000';
  }

  async function rpcCall(to, data) {
    const res = await fetch(RPC_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'eth_call', params: [{ to: to, data: data }, 'latest'] }),
    });
    const j = await res.json();
    if (j.error) throw new Error(j.error.message || 'RPC error');
    return j.result;
  }

  function esc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function fmtTime(ts) {
    return new Date(ts * 1000).toLocaleString();
  }

  async function refreshHolderStatus() {
    if (!account) return;
    try {
      const raw = await rpcCall(CONTRACT_ADDRESS, isAgentIdHolderData(account));
      isHolder = decBool(raw, 0);
      $('agentid-line').textContent = isHolder
        ? 'Agent ID holder — you can create polls and vote.'
        : 'This address holds no Agent ID, so it cannot create polls or vote. Claim an Agent ID in the Binance app first.';
      $('create-btn').disabled = !isHolder;
    } catch (e) {
      $('agentid-line').textContent = 'Could not check Agent ID status: ' + e.message;
    }
  }

  async function connectWallet() {
    if (!window.ethereum) {
      $('account-line').textContent = 'No wallet found. Install MetaMask or open this page in the Binance Wallet browser.';
      return;
    }
    try {
      const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
      account = accounts[0];
      const chainId = await window.ethereum.request({ method: 'eth_chainId' });
      if (chainId !== CHAIN_ID_HEX) {
        try {
          await window.ethereum.request({ method: 'wallet_switchEthereumChain', params: [{ chainId: CHAIN_ID_HEX }] });
        } catch (e) {
          $('account-line').textContent = 'Connected as ' + account + ' — please switch your wallet to BNB Chain (chain 56) to vote.';
        }
      }
      const savedName = localStorage.getItem('agentpolls-display-name') || '';
      $('display-name').value = savedName;
      $('account-line').textContent = 'Connected: ' + account + (savedName ? ' (' + savedName + ')' : '');
      await refreshHolderStatus();
      await loadPolls();
    } catch (e) {
      $('account-line').textContent = 'Connection failed: ' + (e.message || e);
    }
  }

  async function loadPolls() {
    const list = $('polls-list');
    if (!isDeployed()) {
      list.innerHTML = '<p class="muted">The contract is not deployed yet — no polls to show.</p>';
      return;
    }
    try {
      const countRaw = await rpcCall(CONTRACT_ADDRESS, pollCountData());
      const count = Number(decUint(countRaw, 0));
      if (count === 0) {
        list.innerHTML = '<p class="muted">No polls yet. Be the first Agent ID holder to create one.</p>';
        return;
      }
      list.innerHTML = '';
      for (let id = count - 1; id >= 0; id--) {
        const meta = decPollMeta(await rpcCall(CONTRACT_ADDRESS, getPollMetaData(id)));
        const closed = Date.now() / 1000 >= meta.deadline;
        let voted = false;
        if (account) {
          voted = decBool(await rpcCall(CONTRACT_ADDRESS, hasVotedOnData(id, account)), 0);
        }
        const div = document.createElement('div');
        div.className = 'poll';
        let html = '<h3>' + esc(meta.question) + '</h3>'
          + '<p class="muted small">Poll #' + id + ' · by ' + esc(meta.creator)
          + ' · ' + (closed ? 'closed' : 'open until ' + fmtTime(meta.deadline))
          + ' · ' + meta.totalVotes + ' vote' + (meta.totalVotes === 1 ? '' : 's') + '</p>';
        for (let i = 0; i < meta.optionCount; i++) {
          const label = decStringAt(await rpcCall(CONTRACT_ADDRESS, getOptionData(id, i)), 0);
          const votes = Number(decUint(await rpcCall(CONTRACT_ADDRESS, getOptionVotesData(id, i)), 0));
          const pct = meta.totalVotes > 0 ? Math.round((votes / meta.totalVotes) * 100) : 0;
          html += '<div class="option"><div class="option-head"><span>' + esc(label) + '</span>'
            + '<span>' + votes + ' (' + pct + '%)</span></div>'
            + '<div class="bar"><div class="fill" style="width:' + pct + '%"></div></div>'
            + '<button data-poll="' + id + '" data-opt="' + i + '" class="vote-btn"'
            + ((!isHolder || closed || voted || !account) ? ' disabled' : '') + '>Vote</button></div>';
        }
        if (account && voted) html += '<p class="muted small">You already voted on this poll.</p>';
        if (account && !isHolder) html += '<p class="muted small">Only Agent ID holders can vote.</p>';
        div.innerHTML = html;
        list.appendChild(div);
      }
      list.querySelectorAll('.vote-btn').forEach(function (btn) {
        btn.addEventListener('click', function () { castVote(Number(btn.dataset.poll), Number(btn.dataset.opt)); });
      });
    } catch (e) {
      list.innerHTML = '<p class="muted">Could not load polls: ' + esc(e.message) + '</p>';
    }
  }

  async function sendTx(data, summary) {
    if (!window.ethereum) throw new Error('No wallet found.');
    $('create-status').textContent = summary + ' — please review and confirm in your wallet.';
    const txHash = await window.ethereum.request({
      method: 'eth_sendTransaction',
      params: [{ from: account, to: CONTRACT_ADDRESS, data: data, value: '0x0' }],
    });
    return txHash;
  }

  async function castVote(pollId, optionIndex) {
    try {
      const txHash = await sendTx(voteData(pollId, optionIndex), 'Vote on poll #' + pollId + ', option ' + (optionIndex + 1));
      $('create-status').innerHTML = 'Vote sent: <a href="' + BSCSCAN_TX + txHash + '" target="_blank" rel="noopener">' + esc(txHash) + '</a>';
      await loadPolls();
    } catch (e) {
      $('create-status').textContent = 'Vote failed or rejected: ' + (e.message || e);
    }
  }

  function optionInputs() {
    return Array.from(document.querySelectorAll('.q-option')).map(function (el) { return el.value.trim(); });
  }

  function updateCreateSummary() {
    const q = $('q-question').value.trim();
    const opts = optionInputs().filter(function (s) { return s.length > 0; });
    const days = Number($('q-duration').value) / 86400;
    $('create-summary').textContent = q && opts.length >= 2
      ? 'This will create a poll "' + q + '" with ' + opts.length + ' options, open for ' + days + ' day(s). The transaction costs only network gas.'
      : 'Fill in a question and at least 2 options.';
  }

  document.addEventListener('DOMContentLoaded', function () {
    if (!isDeployed()) $('deploy-banner').classList.remove('hidden');
    $('create-btn').disabled = true;
    $('connect-btn').addEventListener('click', connectWallet);
    $('refresh-btn').addEventListener('click', loadPolls);
    $('save-name-btn').addEventListener('click', function () {
      const name = $('display-name').value.trim();
      if (name) localStorage.setItem('agentpolls-display-name', name);
      else localStorage.removeItem('agentpolls-display-name');
      if (account) $('account-line').textContent = 'Connected: ' + account + (name ? ' (' + name + ')' : '');
    });
    $('add-option-btn').addEventListener('click', function () {
      const n = document.querySelectorAll('.q-option').length;
      if (n >= 6) return;
      const label = document.createElement('label');
      label.innerHTML = 'Option ' + (n + 1) + ' <input class="q-option" type="text" maxlength="140" placeholder="Option ' + (n + 1) + '">';
      $('options-box').appendChild(label);
      label.querySelector('input').addEventListener('input', updateCreateSummary);
      updateCreateSummary();
    });
    $('remove-option-btn').addEventListener('click', function () {
      const labels = $('options-box').querySelectorAll('label');
      if (labels.length <= 2) return;
      labels[labels.length - 1].remove();
      updateCreateSummary();
    });
    $('q-question').addEventListener('input', updateCreateSummary);
    $('q-duration').addEventListener('change', updateCreateSummary);
    document.querySelectorAll('.q-option').forEach(function (el) { el.addEventListener('input', updateCreateSummary); });
    $('create-btn').addEventListener('click', async function () {
      const q = $('q-question').value.trim();
      const opts = optionInputs().filter(function (s) { return s.length > 0; });
      const duration = Number($('q-duration').value);
      if (!q || opts.length < 2 || opts.length > 6) {
        $('create-status').textContent = 'Need a question and 2–6 non-empty options.';
        return;
      }
      if (!account) { $('create-status').textContent = 'Connect your wallet first.'; return; }
      if (!isHolder) { $('create-status').textContent = 'Only Agent ID holders can create polls.'; return; }
      try {
        const txHash = await sendTx(createPollData(q, opts, duration), 'Create poll "' + q + '"');
        $('create-status').innerHTML = 'Poll created: <a href="' + BSCSCAN_TX + txHash + '" target="_blank" rel="noopener">' + esc(txHash) + '</a>';
        await loadPolls();
      } catch (e) {
        $('create-status').textContent = 'Create failed or rejected: ' + (e.message || e);
      }
    });
    if (window.ethereum && window.ethereum.request) {
      window.ethereum.request({ method: 'eth_accounts' }).then(function (accs) {
        if (accs && accs.length > 0) connectWallet();
      }).catch(function () { /* stay disconnected */ });
    }
    updateCreateSummary();
    loadPolls();
  });
}

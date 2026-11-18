# Agent Polls — 1 Agent ID = 1 vote

On-chain voting for agent communities, built for the **Binance Agent ID Hackathon**
(Binance Wallet + BNB Chain, 60,000 USDC; submission period 2026-11-18 08:00 UTC –
2026-12-09 08:00 UTC).

Only addresses holding an **Agent ID** can create polls and vote. One vote per
Agent ID per poll, enforced in the contract, final and transparent. No token, no
rewards, no fees, no owner, no admin functions. The contract holds no funds and
cannot move any user's assets.

## How Agent ID is used

The contract calls `balanceOf(address)` on the official SPACE ID Agent ID
registry (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` on BNB Chain) — exactly the
check the hackathon announcement describes. `balanceOf > 0` means the address
holds an Agent ID. That check gates both `createPoll` and `vote`. The frontend
shows the connected wallet's own holding status; a display name can be typed in
by the user themselves and is stored only in their browser — the app never
resolves anyone else's name to an address.

## Contract

`src/AgentPolls.sol` — one contract, no dependencies beyond the registry.

- `createPoll(string question, string[] options, uint256 durationSeconds)` —
  2–6 options, duration 1 hour to 90 days. Returns the poll id.
- `vote(uint256 pollId, uint8 optionIndex)` — one vote per Agent ID per poll;
  reverts on double vote, after the deadline, or for non-holders.
- Views: `pollCount()`, `getPollMeta(pollId)`, `getOption(pollId, i)`,
  `getOptionVotes(pollId, i)`, `getResults(pollId)`, `hasVotedOn(pollId, voter)`,
  `myVote(pollId, voter)`, `isAgentIdHolder(address)`.
- Events: `PollCreated`, `VoteCast`. Custom errors, no owner, no pausing.

## Tests

```bash
forge test
```

21 tests: create/vote happy paths, double-vote, non-holder, deadline (incl. the
exact boundary), option-count limits, empty question/option, duration limits,
invalid option, nonexistent poll, event emission, 6-option polls, sequential ids.

## Gas (measured on local anvil, reproducible with `bash script/measure-gas.sh`)

| Action | Gas | Cost at 0.05 gwei (live BSC price, 2026-11-18) |
| --- | --- | --- |
| Deploy | 1,696,356 | **0.0000848178 BNB** |
| createPoll (2 options) | 219,831 | 0.0000109915 BNB |
| vote | 108,379–111,191 | ~0.0000055 BNB |

## Deploy (mainnet, after top-up — NOT done yet)

The deployer wallet holds ~0.0000469 BNB; deployment alone needs ~0.0000848 BNB
at 0.05 gwei — about 1.8× the current balance. **Top up 0.001 BNB first**
(covers deployment + several polls/votes + gas-price spikes; at 1 gwei the
deployment alone would cost ~0.0017 BNB).

```bash
forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.binance.org --broadcast --private-key <KEY>
```

Then verify the source on BscScan (contract page → Verify & Publish, or
`forge verify-contract <address> src/AgentPolls.sol:AgentPolls --chain 56`),
set `CONTRACT_ADDRESS` in `frontend/app.js`, and host the frontend (see below).

## Frontend

`frontend/` — plain HTML/JS/CSS, no libraries, no build step, no backend.
Reads use the public BSC RPC; writes go through the user's wallet
(`window.ethereum`) and always ask for confirmation in the wallet. Verified:
the hand-rolled ABI encoding matches `cast calldata` byte-for-byte
(`node frontend/test-frontend-abi.js`).

Host it free on GitHub Pages: push this repo to GitHub, then
Settings → Pages → Deploy from branch → `main` → `/frontend`. The site URL
goes in the hackathon submission as the project website.

## Red-lines compliance (hackathon rules)

- No QR-code login, no stored sessions, no auto-signing — every transaction is
  confirmed by the user in their own wallet.
- No unauthorized transfers: the contract is not payable and moves no assets.
- Open source, no owner permissions at all (no mint/pause/withdraw functions).
- No "Binance"/"BNB" in the project name, token name, or domain. The name is
  "Agent Polls". The site states it is not affiliated with Binance.
- No promised returns, no token, no rewards.
- No name-to-wallet lookup of other people: only the caller's own
  `balanceOf` is checked; display names are user-typed, local only.

## Submission

See `SUBMISSION.md` for the channel status and the materials checklist.

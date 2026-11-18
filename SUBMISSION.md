# Agent Polls — hackathon submission pack

## Submission channel — NOT FOUND YET (checked 2026-11-18)

The official announcement
(https://www.binance.com/en/support/announcement/detail/95f5dbe0ea674a48a739b59e046648bf)
says: "Submit your project name, website, contract address(es), Agent ID usage
description, and other required materials during the Submission Period. No
registration needed." — but **the page contains no submission form link**, and
two web searches plus the Binance Square repost of the announcement found no
project-submission form either.

What the pattern from Binance's other hackathons suggests: the project
submission will most likely be a **Binance survey link**
(`binance.com/en/survey/<id>`) published on the announcement page, the Binance
Wallet X account, or Binance Square during the submission period — the earlier
Agent OS Mini Hackathon used exactly that (survey + X post). The X-promotion
part of this hackathon already points at a Binance survey ("Submit your X link
via the official campaign survey").

**Action:** re-check the announcement page and @BinanceWallet on X before
submitting; do not submit through any form link that did not come from
binance.com. Deadline: **2026-12-09 08:00 UTC (15:00 WIB)**.

## Fields the announcement names

- Project name: **Agent Polls**
- Website: GitHub Pages URL of `frontend/` (set up after pushing to GitHub)
- Contract address(es): the deployed `AgentPolls` address on BNB Chain mainnet
- Agent ID usage description: see draft below
- Reward receiving address: the wallet that should receive USDC if the project
  wins (provide during submission)
- Other required materials: most likely the public GitHub repo link; a short
  demo video is recommended (judges need to run it)

One project per team. Each project can receive only one award.

## Agent ID usage description (draft for the form)

> Agent Polls uses Agent ID as the sole identity and access gate. The contract
> calls balanceOf(address) on the official SPACE ID Agent ID registry
> (0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F) and only addresses holding an
> Agent ID can create polls or vote. Each Agent ID gets exactly one vote per
> poll, enforced on-chain; votes are final and transparent. The frontend shows
> the connected wallet's own holding status and lets the user type in their own
> display name locally; it never resolves other people's names to addresses.
> There is no token, no reward, and no fee — it is a governance tool for agent
> communities to make decisions together.

## Pre-submission checklist

- [ ] Top up the deployer wallet with 0.001 BNB (see README.md for the math)
- [ ] Deploy AgentPolls to BNB Chain mainnet (`forge script script/Deploy.s.sol --broadcast`)
- [ ] Verify source on BscScan
- [ ] Set CONTRACT_ADDRESS in frontend/app.js
- [ ] Push repo to GitHub (owner: Ekosty17) and enable GitHub Pages on /frontend
- [ ] Create 2–3 starter polls from the deployer wallet so the site is live
- [ ] Find the official submission form (see "channel" above) and submit before 2026-12-09 08:00 UTC
- [ ] Promote to Agent ID holders (X / Binance Square): the Innovation Award
      needs at least 30 Agent ID addresses interacting with the contract during
      the submission period, and the Growth Award ranks on interacting addresses,
      volume and transaction count

## What is already done

- Contract written, 21/21 tests passing (`forge test`)
- Gas measured on anvil: deploy 1,696,356; createPoll 219,831; vote ~108k–111k
- Frontend built (plain HTML/JS, no libraries); ABI encoding verified
  byte-for-byte against `cast calldata`
- Repo committed locally (no push, no deploy, no submit)

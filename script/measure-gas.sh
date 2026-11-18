#!/usr/bin/env bash
# Measure real deployment + interaction gas on a local anvil chain.
# Runs script/MeasureGas.s.sol (deploys MockAgentId + AgentPolls, creates a
# 2-option poll, casts two votes) and prints gasUsed per transaction.
# Usage: bash script/measure-gas.sh
set -euo pipefail
export PATH="$HOME/.foundry/bin:$PATH"
RPC=http://127.0.0.1:8545

cd "$(dirname "$0")/.."
forge build --quiet

setsid nohup anvil --port 8545 --silent > /tmp/agent-polls-anvil.log 2>&1 < /dev/null &
echo $! > /tmp/agent-polls-anvil.pid
sleep 3
cleanup() { kill "$(cat /tmp/agent-polls-anvil.pid)" 2>/dev/null || true; }
trap cleanup EXIT

forge script script/MeasureGas.s.sol --tc MeasureGas --rpc-url "$RPC" --broadcast --start-fresh --quiet
python3 - << 'EOF'
import json, glob
f = sorted(glob.glob('broadcast/MeasureGas.s.sol/31337/run-*.json'))[-1]
d = json.load(open(f))
for tx, rec in zip(d['transactions'], d['receipts']):
    name = tx.get('contractName') or ''
    fn = tx.get('function') or 'deploy'
    print(f"{name} {fn} gasUsed={int(rec['gasUsed'], 16)} status={rec.get('status')}")
EOF

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AgentPolls.sol";

/// Minimal stand-in for the SPACE ID Agent ID registry (ERC-721 balanceOf).
contract MockAgentId {
    mapping(address => uint256) public balances;

    function setBalance(address account, uint256 amount) external {
        balances[account] = amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}

/// Local-only gas measurement against anvil. Deploys MockAgentId + AgentPolls,
/// creates a 2-option poll and casts two votes. Read gasUsed per transaction
/// from broadcast/MeasureGas.s.sol/31337/run-latest.json.
/// NOT for mainnet — mainnet deploy uses script/Deploy.s.sol.
/// Run: forge script script/MeasureGas.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
contract MeasureGas is Script {
    uint256 constant PK0 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 constant PK1 = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    function run() external {
        address voter1 = vm.addr(PK0);
        address voter2 = vm.addr(PK1);

        vm.startBroadcast(PK0);
        MockAgentId registry = new MockAgentId();
        registry.setBalance(voter1, 1);
        registry.setBalance(voter2, 1);
        AgentPolls polls = new AgentPolls(address(registry));
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";
        polls.createPoll("Should agents vote on-chain?", options, 7 days);
        polls.vote(0, 0);
        vm.stopBroadcast();

        vm.startBroadcast(PK1);
        polls.vote(0, 1);
        vm.stopBroadcast();

        console.log("AgentPolls:", address(polls));
        console.log("MockAgentId:", address(registry));
    }
}

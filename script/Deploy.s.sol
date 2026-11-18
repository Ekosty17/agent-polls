// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AgentPolls.sol";

/// @notice Deploy AgentPolls to BNB Chain mainnet (chain id 56).
/// @dev Run: forge script script/Deploy.s.sol --rpc-url <BSC_RPC> --broadcast --private-key <KEY>
///      The deployer needs enough BNB for deployment gas (see README.md).
///      After deployment, verify on BscScan (web form or `forge verify-contract`).
contract Deploy is Script {
    // SPACE ID Agent ID registry on BNB Chain mainnet.
    address constant AGENT_ID_REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function run() external returns (AgentPolls) {
        vm.startBroadcast();
        AgentPolls polls = new AgentPolls(AGENT_ID_REGISTRY);
        vm.stopBroadcast();
        console.log("AgentPolls deployed at:", address(polls));
        console.log("Agent ID registry:", AGENT_ID_REGISTRY);
        return polls;
    }
}

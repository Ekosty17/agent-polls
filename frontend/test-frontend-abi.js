// Node test for the frontend ABI helpers in frontend/app.js.
// Verifies our hand-rolled encoding against `cast calldata` and the
// decoding against `cast abi-decode`. Run: node frontend/test-frontend-abi.js
const assert = require('assert');
const { execSync } = require('child_process');
const abi = require('./app.js');

function cast(args) {
  return execSync('cast ' + args, { encoding: 'utf8' }).trim();
}

// 1. createPoll encoding matches cast exactly.
const ours = abi.createPollData('Should agents vote on-chain?', ['Yes', 'No'], 604800);
const theirs = cast('calldata "createPoll(string,string[],uint256)" "Should agents vote on-chain?" "[Yes,No]" 604800');
assert.strictEqual(ours.toLowerCase(), theirs.toLowerCase(), 'createPoll calldata mismatch');
console.log('createPoll encoding OK:', ours.slice(0, 42) + '...');

// 2. vote encoding matches cast exactly.
const oursVote = abi.voteData(0, 1);
const theirsVote = cast('calldata "vote(uint256,uint8)" 0 1');
assert.strictEqual(oursVote.toLowerCase(), theirsVote.toLowerCase(), 'vote calldata mismatch');
console.log('vote encoding OK:', oursVote);

// 3. getPollMeta decoding: build a fake return with cast, decode with our code.
const fake = cast('abi-encode "f(address,string,uint256,uint256,uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 "Should agents vote on-chain?" 1795000000 3 2');
const meta = abi.decPollMeta(fake);
assert.strictEqual(meta.creator.toLowerCase(), '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266');
assert.strictEqual(meta.question, 'Should agents vote on-chain?');
assert.strictEqual(meta.deadline, 1795000000);
assert.strictEqual(meta.totalVotes, 3);
assert.strictEqual(meta.optionCount, 2);
console.log('getPollMeta decoding OK:', JSON.stringify(meta));

// 4. string return decoding (getOption).
const fakeStr = cast('abi-encode "f(string)" "Yes"');
assert.strictEqual(abi.decStringAt(fakeStr, 0), 'Yes');
console.log('string decoding OK: "Yes"');

// 5. bool + uint decoding (hasVotedOn / pollCount).
const fakeBool = cast('abi-encode "f(bool)" true');
assert.strictEqual(abi.decBool(fakeBool, 0), true);
const fakeCount = cast('abi-encode "f(uint256)" 7');
assert.strictEqual(abi.decUint(fakeCount, 0), 7n);
console.log('bool/uint decoding OK');

console.log('ALL FRONTEND ABI TESTS PASSED');

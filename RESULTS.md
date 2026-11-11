# Results

Recorded evidence for the EIP-7702 delegated ERC-20 approval policy prototype. Local outputs were captured on 2026-11-11. The public demonstration ran on Ethereum Sepolia (chain ID `11155111`) using the project's freely mintable mock token, which has no real value.

## Local Foundry verification

Toolchain: Foundry 1.9.0; Solidity compiler 0.8.30; Prague EVM target.

| Command | Outcome |
|---|---|
| `forge build` | Successful compilation |
| `forge test -vv` | 16 passed, 0 failed, 0 skipped across 2 suites |
| `DelegationPolicyTest` | 15 passed, including 256 fuzz runs |
| `DelegationLifecycleTest` | 1 passed; local test gas figure 870,764 |

The lifecycle test gas figure is from Foundry's local test execution, not a network transaction or a controlled gas benchmark. The build emitted `reentrancy-events` lint warnings for events after external token calls; the warnings did not cause test failures.

## Sepolia observed state

| Stage | Owner delegation code | Allowance (tokens) | Spender token balance (tokens) |
|---|---|---:|---:|
| After delegated approval | Present | 10 | 0 |
| After spender transfer of 4 | Present | 6 | 4 |
| After delegation reset | `0x` (cleared) | 6 | 4 |
| After separate token approval cleanup | `0x` | 0 | 4 |

This run demonstrates that clearing EIP-7702 delegation does not itself erase an ERC-20 allowance stored by the token. The owner separately called the token's `approve(spender, 0)`. The four tokens already transferred to the spender remained with the spender.

Policy address: `0xfdd7664f90779f67de7ed9da03183392465e53ec`

Mock token address: `0x49d2c63a799a80c841db2f57d9e337c6ee6e1c8e`

## Sepolia transaction evidence

All listed transactions have successful receipts (`status: 0x1`). Gas is the receipt's `gasUsed` for this single run, not a controlled comparison.

| Operation | Block | Gas used | Sepolia transaction |
|---|---:|---:|---|
| Deploy policy | 12111402 | 3,054,839 | [0xdf3a5b5fe6b901cd2fca8dedae7cc1d99b23059fdb038e01679b05dee48e8767](https://sepolia.etherscan.io/tx/0xdf3a5b5fe6b901cd2fca8dedae7cc1d99b23059fdb038e01679b05dee48e8767) |
| Deploy mock token | 12111402 | 2,620,321 | [0x68be8a6404af1f451d3d3ccb4accc8c329fcf7c2fb95e416bb27e1e5c361684a](https://sepolia.etherscan.io/tx/0x68be8a6404af1f451d3d3ccb4accc8c329fcf7c2fb95e416bb27e1e5c361684a) |
| Initial mock-token mint | 12111402 | 128,151 | [0x8e8a23dab1d91b813c9c2063af08018fbee08d45d158ae9a99e360857cf2f924](https://sepolia.etherscan.io/tx/0x8e8a23dab1d91b813c9c2063af08018fbee08d45d158ae9a99e360857cf2f924) |
| Set token rule | 12111554 | 282,530 | [0x1c0fec0cb7a0b10436d933991f20eeb19dc50b8358d1e92d16e557fe115c1d43](https://sepolia.etherscan.io/tx/0x1c0fec0cb7a0b10436d933991f20eeb19dc50b8358d1e92d16e557fe115c1d43) |
| Approve 10 tokens within cap | 12111555 | 138,677 | [0x70262f151db82161ba17c9ab44c838bbe4ad7acb607deca09783475d1deeaabf](https://sepolia.etherscan.io/tx/0x70262f151db82161ba17c9ab44c838bbe4ad7acb607deca09783475d1deeaabf) |
| Mint tokens to current owner | 12111715 | 128,151 | [0x702533d9ca24c6f578608b9366f31e90d991b4782c4c5a90e4b9d586b100de27](https://sepolia.etherscan.io/tx/0x702533d9ca24c6f578608b9366f31e90d991b4782c4c5a90e4b9d586b100de27) |
| Spender transfers 4 tokens | 12111724 | 155,836 | [0xba3ad8e363c23b4438eded5bec1c650eca01458a98b7f3b427e5e22b2e5b1184](https://sepolia.etherscan.io/tx/0xba3ad8e363c23b4438eded5bec1c650eca01458a98b7f3b427e5e22b2e5b1184) |
| Reset delegation | 12111743 | 19,816 | [0x93f681b341a309b53c89fe4e3fe8c9a2cb9f59fbb1b49019a79e018699c6a9cb](https://sepolia.etherscan.io/tx/0x93f681b341a309b53c89fe4e3fe8c9a2cb9f59fbb1b49019a79e018699c6a9cb) |
| Clear remaining allowance | 12111744 | 24,064 | [0x4f6161af4645830e8f6b326e1a83ecca5083fcb5d691b32dee379896027f33ed](https://sepolia.etherscan.io/tx/0x4f6161af4645830e8f6b326e1a83ecca5083fcb5d691b32dee379896027f33ed) |

## Limits

These results cover the local Foundry tests and one Sepolia run with the project mock token. They are not an audit, formal proof, real-token compatibility result, multi-client evaluation, or controlled gas benchmark. The policy only constrains calls routed through this implementation; the owner can authorize different delegated code.

# EIP-7702 Delegation Policy Prototype

A small Solidity policy for ERC-20 approvals when the policy code is delegated to an EOA under EIP-7702. It configures one spender and an approval cap per token, limits changes to account self-calls, and supports explicit allowance cleanup.

The project implements the policy directly; no external Solidity library implements its authorization or approval-cap logic. Foundry is used to compile, test, simulate, and broadcast transactions.

## What is in this repository

- `src/DelegationPolicy.sol` — policy implementation.
- `src/mocks/ProjectTestToken.sol` — freely mintable demo token; it has no real value.
- `test/` — policy unit/fuzz tests and a local Prague EIP-7702 lifecycle test.
- `script/` — optional Sepolia deployment and lifecycle scripts.
- `foundry.toml` — compiler and test configuration.
- `RESULTS.md` — recorded local test results and public Sepolia transaction evidence.

## Requirements

For a Windows 11 computer, use WSL 2 with Ubuntu. Install Foundry in Ubuntu. The recorded run used Foundry 1.9.0 and Solidity 0.8.30.

Local build and tests need no wallet, RPC endpoint, API key, or `.env` file. Sepolia steps are optional and require a Sepolia RPC endpoint and test ETH.

### Install WSL 2 and Ubuntu if needed

Open PowerShell as Administrator and run:

```powershell
wsl --install -d Ubuntu
```

Restart Windows if prompted, open Ubuntu from the Start menu, and finish the first-launch username/password setup. If Ubuntu is already installed, continue in its terminal.

### Install Foundry in Ubuntu

```bash
curl -L https://foundry.paradigm.xyz | bash
```

Close and reopen Ubuntu, then run:

```bash
foundryup
forge --version
```

## Clone and run the local checks

In Ubuntu:

```bash
git clone https://github.com/saiprabhav31/cs731.git
cd cs731
forge --version
forge build
forge test -vv
```

Expected result: build succeeds and 16 tests pass across 2 suites (15 policy tests, including 256 fuzz runs, and 1 EIP-7702 lifecycle test). The lifecycle test runs on Foundry's local Prague EVM; it is not a public-network transaction.

For detailed lifecycle traces:

```bash
forge test --match-test testDelegationClearDoesNotClearTokenAllowance -vvvv
```

## Optional: repeat the Sepolia demo

Use only disposable test accounts and the project mock token. Never use a mainnet wallet. Do not share or commit private keys, RPC API tokens, `.env`, or Foundry `cache/` files. The repository `.gitignore` excludes them.

1. Create separate owner and spender accounts and fund both with Sepolia ETH from a faucet.
2. Get an Ethereum Sepolia JSON-RPC URL from a provider.
3. In Ubuntu, create and edit the local environment file:

   ```bash
   cp .env.example .env
   nano .env
   ```

   Set `SEPOLIA_RPC_URL`, both private keys and their matching addresses. Keep `POLICY_ADDRESS` and `TOKEN_ADDRESS` as placeholders until deployment. `.env` is ignored by Git.
4. Load the variables and check the network:

   ```bash
   set -a
   source .env
   set +a
   cast chain-id --rpc-url "$SEPOLIA_RPC_URL"
   ```

   It must print `11155111` (Sepolia). Never paste the output of `cat .env` or share the file.
5. Simulate deployment first, then broadcast it:

   ```bash
   forge script script/DeploySepolia.s.sol:DeploySepolia --rpc-url "$SEPOLIA_RPC_URL"
   forge script script/DeploySepolia.s.sol:DeploySepolia --rpc-url "$SEPOLIA_RPC_URL" --broadcast
   ```

   Copy the printed policy and token addresses into `.env`, save it, then reload the variables with `set -a; source .env; set +a`.
6. Simulate and broadcast the owner delegation, rule setup, and 10-token approval:

   ```bash
   forge script script/ActivateAndApproveSepolia.s.sol:ActivateAndApproveSepolia --rpc-url "$SEPOLIA_RPC_URL"
   forge script script/ActivateAndApproveSepolia.s.sol:ActivateAndApproveSepolia --rpc-url "$SEPOLIA_RPC_URL" --broadcast
   ```
7. If the current owner has no mock tokens, simulate and broadcast the mint script. The demo token is freely mintable and valueless:

   ```bash
   forge script script/MintOwnerTokensSepolia.s.sol:MintOwnerTokensSepolia --rpc-url "$SEPOLIA_RPC_URL"
   forge script script/MintOwnerTokensSepolia.s.sol:MintOwnerTokensSepolia --rpc-url "$SEPOLIA_RPC_URL" --broadcast
   ```
8. Fund the spender account with Sepolia ETH, then simulate and broadcast the 4-token spend:

   ```bash
   forge script script/SpendResidualAllowanceSepolia.s.sol:SpendResidualAllowanceSepolia --rpc-url "$SEPOLIA_RPC_URL"
   forge script script/SpendResidualAllowanceSepolia.s.sol:SpendResidualAllowanceSepolia --rpc-url "$SEPOLIA_RPC_URL" --broadcast
   cast call "$TOKEN_ADDRESS" "allowance(address,address)(uint256)" "$OWNER_ADDRESS" "$SPENDER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL"
   ```

   Expected allowance: `6000000000000000000` (6 tokens); spender receives 4 tokens.
9. Simulate then broadcast reset and cleanup. Run the broadcast directly in Ubuntu without piping it through `tee`; Foundry needs an interactive terminal for this sequence:

   ```bash
   forge script script/ResetAndCleanSepolia.s.sol:ResetAndCleanSepolia --rpc-url "$SEPOLIA_RPC_URL"
   forge script script/ResetAndCleanSepolia.s.sol:ResetAndCleanSepolia --rpc-url "$SEPOLIA_RPC_URL" --broadcast
   cast code "$OWNER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL"
   cast call "$TOKEN_ADDRESS" "allowance(address,address)(uint256)" "$OWNER_ADDRESS" "$SPENDER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL"
   ```

   Expected final values: owner code `0x`, allowance `0`. The spender retains the 4 tokens already transferred.

The recorded transactions and observed results are in [`RESULTS.md`](RESULTS.md). Gas figures there are from one run and are not a controlled benchmark.

## Scope and limitations

This is an educational prototype, not an audited wallet or formal proof. It only constrains calls routed through this policy; the owner can authorize different delegated code. Tests and the Sepolia demo cover the stated policy and mock-token paths, not every ERC-20 token or execution client.

# AevumAgentPay Protocol — End-to-End `tUSD8` Payment & Autonomous AI Agent Hub

**Bounty Submission:** Aevum Builder Challenge #1 (by QDay on DoraHacks)  
**Target Network:** QDay Aevum Testnet (`Chain ID: 44005` / `0xABE5`)  
**Official Stablecoin:** `tUSD8` (`0x456569838f1d43009A91ebA4263147Afd7233483`)

---

## 1. Problem Statement
Business stablecoin payments suffer from three critical bottlenecks:
1. **Invoice Redirection & Phishing Fraud**: Traditional crypto transfers lack recipient name verification (Confirmation of Payee), causing irreversible loss when an attacker swaps an address.
2. **Discrete Payroll Friction**: Paying global contributors bi-weekly or monthly locks up working capital and requires repetitive batch transactions.
3. **Unbounded AI Agent Wallets**: Giving an autonomous AI agent a raw private key to pay for APIs or cloud compute creates catastrophic drainage risk without on-chain spending guardrails.

---

## 2. Solution & Architecture: `AevumAgentPay`
`AevumAgentPay` is a unified smart contract and web interface built natively for the **QDay Aevum Testnet** (`tUSD8`):

- **Confirmation of Payee (CoP) Smart Invoices**: Every invoice stores a cryptographic `keccak256(legalBusinessName)` commitment on-chain. Settlement in `tUSD8` only executes if the payer (human or AI agent) verifies the exact registered payee identity.
- **Per-Second `tUSD8` Payroll & Vesting Streams**: Employers lock `tUSD8` into continuous streams that vest every second with 6-decimal precision, allowing contributors to claim accrued earnings at any time.
- **ERC-8004 Autonomous AI Agent Mandates**: Principals delegate `tUSD8` payment authority to an AI Agent bounded by hardcoded on-chain guardrails (`maxPerTx`, `dailyLimit`, and mandatory CoP verification).

```
[ Human Treasury / Principal ]
              │
              ▼ (Approves tUSD8 & Configures Rules)
┌──────────────────────────────────────────────────────────┐
│            AevumAgentPay.sol (Chain ID: 44005)           │
├──────────────────┬───────────────────┬───────────────────┤
│ 1. CoP Invoices  │ 2. Payroll Stream │ 3. ERC-8004 Agent │
│ keccak256(Payee) │ Per-Second Vest   │ MaxTx & DailyCap  │
└────────┬─────────┴─────────┬─────────┴─────────┬─────────┘
         │                   │                   │
         ▼                   ▼                   ▼
   [ Verified B2B ]   [ Contributors ]   [ Autonomous AI ]
```

---

## 3. QDay Aevum Testnet Parameters
- **Network Name**: QDay Aevum Testnet
- **Chain ID**: `44005` (`0xABE5`)
- **RPC URL**: `https://rpc-test.qday.info`
- **WebSocket**: `wss://rpc-test.qday.info`
- **Block Explorer**: `https://explorer-test.qday.info`
- **Gas Currency**: `tQDAY` (18 decimals)
- **`tUSD8` Token Contract**: `0x456569838f1d43009A91ebA4263147Afd7233483` (6 decimals)

---

## 4. Quick Start & Docker Deployment

### Run Local Web Application
```bash
python -m http.server 8081 --directory web
```
Then open `http://localhost:8081` in your browser.

### Run via Docker
```bash
docker build -t aevum-agent-pay .
docker run -p 8081:8081 aevum-agent-pay
```

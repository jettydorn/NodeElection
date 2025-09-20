# NodeElection

A stake-weighted voting system for blockchain validator selection and rotation built on the Stacks blockchain using Clarity smart contracts.

## Overview

NodeElection is a decentralized governance system that allows stakeholders to participate in validator elections through stake-weighted voting. The system manages validator registration, election cycles, and automatic rotation periods to ensure fair and secure validator selection for blockchain networks.

## Features

- **Stake-weighted Voting**: Vote power is proportional to staked STX tokens
- **Validator Registration**: Validators must meet minimum stake requirements to participate
- **Election Management**: Automated election cycles with configurable duration
- **Secure Voting**: One vote per stakeholder per election with transparent tracking
- **Administrative Controls**: Contract admin can manage election lifecycle
- **Flexible Staking**: Users can stake and unstake STX tokens at any time
- **Comprehensive Queries**: Rich read-only functions for system state inspection

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity 2.0
- **Minimum Validator Stake**: 1 STX (1,000,000 micro-STX)
- **Election Duration**: 1,008 blocks (~1 week, assuming 10-minute blocks)
- **Maximum Validators**: 21 active validators
- **Vote Weight**: Based on staked STX amount

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) CLI tool
- Node.js 18+ and npm
- Stacks wallet for deployment

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd NodeElection
```

2. Navigate to the contract directory:
```bash
cd NodeElection_contract
```

3. Install dependencies:
```bash
npm install
```

4. Check contract syntax:
```bash
clarinet check
```

5. Run tests:
```bash
npm test
```

## Usage Examples

### Staking Tokens

Before participating in elections, users must stake STX tokens:

```clarity
;; Stake 5 STX tokens
(contract-call? .NodeElection stake-tokens u5000000)
```

### Registering as a Validator

Validators must stake at least 1 STX before registering:

```clarity
;; Register as validator candidate (requires 1+ STX staked)
(contract-call? .NodeElection register-validator)
```

### Starting an Election

Only the contract admin can initiate elections:

```clarity
;; Start new election (admin only)
(contract-call? .NodeElection start-election)
```

### Voting for Validators

Stakeholders can vote during active elections:

```clarity
;; Vote for a validator using their principal address
(contract-call? .NodeElection vote-for-validator 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)
```

### Finalizing Elections

Admins finalize elections after the voting period ends:

```clarity
;; Finalize current election (admin only)
(contract-call? .NodeElection finalize-election)
```

## Contract Functions

### Public Functions

#### Staking Functions
- `stake-tokens(amount)` - Stake STX tokens to participate in voting
- `unstake-tokens(amount)` - Withdraw staked STX tokens

#### Validator Functions
- `register-validator()` - Register as validator candidate (requires minimum stake)

#### Election Functions
- `start-election()` - Start new election (admin only)
- `vote-for-validator(validator)` - Vote for validator in current election
- `finalize-election()` - Finalize current election (admin only)

#### Administrative Functions
- `set-contract-admin(new-admin)` - Change contract administrator

### Read-Only Functions

#### Validator Queries
- `get-validator(validator)` - Get validator information
- `get-validator-count()` - Get total number of registered validators
- `get-validator-votes(validator, election-id)` - Get votes for validator in specific election

#### Election Queries
- `get-current-election()` - Get current election details
- `get-election(election-id)` - Get specific election information
- `get-current-election-id()` - Get current election ID
- `is-election-active()` - Check if election is currently active

#### Voter Queries
- `get-voter-record(voter, election-id)` - Get voter's record for specific election
- `get-stake(staker)` - Get user's staked amount

#### Administrative Queries
- `get-contract-admin()` - Get current contract administrator

## Data Structures

### Validators Map
```clarity
{
  stake: uint,           ;; Validator's stake amount
  votes-received: uint,  ;; Total votes received (historical)
  is-active: bool,       ;; Currently active validator status
  joined-at: uint        ;; Block height when registered
}
```

### Elections Map
```clarity
{
  start-block: uint,     ;; Election start block
  end-block: uint,       ;; Election end block
  total-votes: uint,     ;; Total vote weight in election
  is-finalized: bool     ;; Election completion status
}
```

### Voter Records Map
```clarity
{
  voted-for: principal,  ;; Validator voted for
  vote-weight: uint,     ;; Weight of the vote (stake amount)
  voted-at: uint         ;; Block height when vote was cast
}
```

## Deployment Guide

### Local Deployment (Devnet)

1. Start local devnet:
```bash
clarinet integrate
```

2. Deploy contract:
```bash
clarinet deploy --devnet
```

### Testnet Deployment

1. Configure testnet settings in `settings/Testnet.toml`

2. Deploy to testnet:
```bash
clarinet deploy --testnet
```

### Mainnet Deployment

1. Update mainnet configuration in `settings/Mainnet.toml`

2. Deploy to mainnet:
```bash
clarinet deploy --mainnet
```

## Security Considerations

### Access Controls
- Election management restricted to contract admin
- Validator registration requires minimum stake
- One vote per stakeholder per election enforced

### Economic Security
- Minimum validator stake prevents spam registration
- Vote weight tied to economic stake creates proper incentives
- Staking mechanism ensures voter commitment

### Technical Security
- All state changes validated through assertions
- Overflow protection in arithmetic operations
- Proper error handling for edge cases

### Known Limitations
- Validator selection algorithm is simplified in current implementation
- No slashing mechanism for malicious validators
- Fixed election duration cannot be modified after deployment

## Error Codes

- `u100` - Owner/admin only operation
- `u101` - Resource not found
- `u102` - Resource already exists
- `u103` - Insufficient stake
- `u104` - Election not active
- `u105` - Already voted in this election
- `u106` - Invalid validator
- `u107` - Election has ended
- `u108` - No active election

## Development

### Running Tests

```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:report

# Watch mode for development
npm run test:watch
```

### Project Structure

```
NodeElection_contract/
├── contracts/
│   └── NodeElection.clar     # Main contract
├── tests/
│   └── NodeElection.test.ts  # Test suite
├── settings/
│   ├── Devnet.toml          # Local development config
│   ├── Testnet.toml         # Testnet configuration
│   └── Mainnet.toml         # Mainnet configuration
├── Clarinet.toml            # Project configuration
└── package.json             # Dependencies and scripts
```

## License

This project is licensed under the ISC License.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

For questions or support, please open an issue in the repository.
# ☀️ Community Solar Panel Shares

A Clarity smart contract that enables community ownership of solar panels through a share-based system. Own a piece of renewable energy infrastructure and earn rewards based on energy production! 🌱

## 🎯 Overview

This contract allows users to:
- 📋 Register solar panels with specific capacity and share information
- 💰 Buy shares in solar panels to become partial owners
- ⚡ Record energy production from panels
- 🎁 Claim rewards proportional to their ownership shares
- 🔄 Trade shares with other users through an offer system
- 📊 Track energy production and reward distribution

## 🚀 Quick Start

### Prerequisites
- Clarinet CLI installed
- Node.js and npm installed

### Installation
```bash
git clone https://github.com/your-repo/Community-Solar-Panel-Shares
cd Community-Solar-Panel-Shares
npm install
```

### Testing
```bash
clarinet check    # Check contract syntax
npm test          # Run tests
```

## 📖 Contract Functions

### 🔧 Administrative Functions

#### `register-panel`
Register a new solar panel for community ownership
```clarity
(register-panel "Location" capacity total-shares share-price)
```
- Only contract owner can register panels
- Returns panel ID

#### `record-energy-production`
Record energy production for a specific panel
```clarity
(record-energy-production panel-id energy-amount)
```
- Only panel owner can record production

### 💎 Share Management

#### `buy-shares`
Purchase shares in a solar panel
```clarity
(buy-shares panel-id shares-amount)
```
- Transfers STX to panel owner
- Updates share ownership

#### `create-share-offer`
Create an offer to sell your shares
```clarity
(create-share-offer panel-id shares-amount price-per-share)
```

#### `accept-share-offer`
Accept someone's share offer
```clarity
(accept-share-offer panel-id seller shares-amount)
```

#### `cancel-share-offer`
Cancel your own share offer
```clarity
(cancel-share-offer panel-id)
```

### 🏆 Rewards

#### `claim-rewards`
Claim energy production rewards based on your shares
```clarity
(claim-rewards panel-id)
```
- Rewards calculated proportionally to ownership
- Updates last claim block

### 📊 Read-Only Functions

#### `get-panel-info`
Get complete information about a solar panel
```clarity
(get-panel-info panel-id)
```

#### `get-user-panel-shares`
Get user's shares in a specific panel
```clarity
(get-user-panel-shares panel-id user-principal)
```

#### `get-user-total-shares`
Get user's total shares across all panels
```clarity
(get-user-total-shares user-principal)
```

#### `get-contract-stats`
Get overall contract statistics
```clarity
(get-contract-stats)
```

#### `calculate-potential-reward`
Calculate potential rewards for a user
```clarity
(calculate-potential-reward panel-id user-principal)
```

## 🔄 Typical Workflow

1. **Panel Registration** 🏗️
   - Contract owner registers solar panels with location, capacity, and share details

2. **Share Purchase** 💰
   - Users buy shares in available panels
   - STX is transferred to panel owner

3. **Energy Production** ⚡
   - Panel owners record energy production regularly
   - Energy data is stored on-chain

4. **Reward Claims** 🎁
   - Share holders claim rewards based on their ownership percentage
   - Rewards calculated from total energy produced

5. **Share Trading** 🔄
   - Users can create offers to sell shares
   - Other users can accept offers to buy shares

## 💡 Example Usage

```clarity
;; Register a panel (owner only)
(contract-call? .community-solar register-panel "California Solar Farm" u1000 u100 u50)

;; Buy 10 shares at 50 STX each (total: 500 STX)
(contract-call? .community-solar buy-shares u1 u10)

;; Record 500 units of energy production
(contract-call? .community-solar record-energy-production u1 u500)

;; Claim rewards
(contract-call? .community-solar claim-rewards u1)

;; Create offer to sell 5 shares at 60 STX each
(contract-call? .community-solar create-share-offer u1 u5 u60)
```

## 🛠️ Technical Details

- **Language**: Clarity
- **Blockchain**: Stacks
- **Share Precision**: Based on 1000 unit calculations
- **Reward Distribution**: Proportional to ownership percentage
- **Energy Tracking**: Per panel, per block height

## 🔐 Security Features

- Owner-only functions for panel registration and energy recording
- Share ownership verification before trades
- Reward claim limiting (once per block)
- Input validation for all parameters

## 📈 Contract Statistics

The contract tracks:
- Total number of registered panels
- Total energy produced across all panels
- Total rewards distributed to shareholders
- Individual user share ownership


## 📝 License

MIT License - see LICENSE file for details

---

*Powering communities with shared renewable energy! 🌍💚*

# 🎲 Prediction Pool - Decentralized Prediction Markets

## Overview

**Prediction Pool** is an innovative, production-ready Clarity smart contract that enables anyone to create and trade prediction markets on real-world events. Unlike traditional betting platforms, Prediction Pool uses automated market maker (AMM) principles where prices dynamically adjust based on pool sizes, creating a self-balancing, decentralized prediction market.

## 🎯 Revolutionary Innovation

### Why Prediction Pool Changes Everything:

**Traditional Prediction Market Problems:**
- ❌ Centralized operators control outcomes
- ❌ High fees (10-20%)
- ❌ Geographic restrictions
- ❌ Limited market creation
- ❌ Opaque odds manipulation
- ❌ Withdrawal delays

**Prediction Pool Solutions:**
- ✅ Decentralized, transparent resolution
- ✅ Only 2% platform fee
- ✅ Global, permissionless access
- ✅ Anyone can create markets
- ✅ Algorithmic pricing (AMM-style)
- ✅ Instant settlements on-chain

## 🌟 Groundbreaking Features

### 1. **Dynamic AMM-Style Pricing**
Unlike fixed-odds betting, prices automatically adjust based on pool sizes:

```
YES Price = (YES Pool / Total Pool) × 100
NO Price = (NO Pool / Total Pool) × 100
```

**Example:**
- Initial: 50 STX YES, 50 STX NO → 50% YES, 50% NO
- After 100 STX YES bet: 150 YES, 50 NO → 75% YES, 25% NO
- Market self-corrects as people bet on undervalued outcomes

### 2. **Parimutuel Payout System**
Winners split the entire pool proportionally:
- All losing bets go into the prize pool
- Winners receive proportional share
- 2% platform fee only on total pool
- No house edge on individual bets

**Payout Formula:**
```
Your Payout = (Your Bet / Winning Pool) × (Total Pool - Fee)
```

### 3. **Comprehensive Market Lifecycle**
- **Active Phase**: Accept bets until deadline
- **Resolution Window**: Creator resolves outcome
- **Settlement Phase**: Winners claim payouts
- **Emergency Procedures**: Auto-refund if unresolved

### 4. **Advanced Statistics Tracking**
- Real-time price updates
- Participant counts (YES/NO bettors)
- Largest position tracking
- Last trade price history
- Total volume per market
- Individual position tracking

### 5. **Multi-Layer Security**
✅ Creator-only resolution (prevents tampering)  
✅ Time-locked deadlines (prevents late bets)  
✅ Emergency withdrawal (30 days after deadline)  
✅ Admin override (15 days after resolution window)  
✅ Claim-once protection (prevents double withdrawals)  
✅ Minimum bet amounts (prevents spam)  

### 6. **Gas-Optimized Design**
- Efficient pool calculations
- Single-pass payout logic
- Minimal storage operations
- Optimized price calculations
- Batch-friendly operations

## 💡 Powerful Use Cases

### 1. **Sports Predictions**
```clarity
;; Create market for championship game
(contract-call? .prediction-pool create-market
  u"Will Lakers win the 2026 NBA Championship?"
  u"Official outcome based on NBA Finals result. Market resolves within 24 hours of series conclusion."
  u"NBA.com official standings"
  u52560   ;; Betting closes 1 year from now
  u144     ;; Resolution within 1 day after close
  "sports")
;; Returns: (ok u1)
```

### 2. **Crypto Price Predictions**
```clarity
(contract-call? .prediction-pool create-market
  u"Will Bitcoin reach $100,000 by Dec 31, 2025?"
  u"Market resolves YES if BTC/USD price on CoinGecko reaches or exceeds $100,000 at any point before midnight UTC on December 31, 2025."
  u"CoinGecko BTC/USD historical data"
  u26280   ;; ~6 months
  u72      ;; Resolve within 12 hours
  "crypto")
```

### 3. **Political Events**
```clarity
(contract-call? .prediction-pool create-market
  u"Will there be a new Bitcoin ETF approved in Q1 2026?"
  u"YES if SEC approves at least one new spot Bitcoin ETF between Jan 1 and Mar 31, 2026. Based on official SEC announcements."
  u"SEC.gov press releases"
  u13140   ;; ~3 months
  u720     ;; 5 days to resolve
  "politics")
```

### 4. **Technology Milestones**
```clarity
(contract-call? .prediction-pool create-market
  u"Will Stacks reach 1M daily active addresses by 2026?"
  u"YES if Stacks blockchain records 1 million unique daily active addresses in any single day during 2026. Verified via blockchain explorers."
  u"Stacks Explorer API data"
  u52560   ;; 1 year
  u1440    ;; 10 days to verify
  "technology")
```

### 5. **Entertainment & Pop Culture**
```clarity
(contract-call? .prediction-pool create-market
  u"Will the next Star Wars movie gross $1B worldwide?"
  u"YES if the next theatrical Star Wars film release reaches $1 billion in worldwide box office revenue according to Box Office Mojo."
  u"Box Office Mojo official data"
  u78840   ;; ~18 months
  u2160    ;; 15 days to confirm
  "entertainment")
```

### 6. **Science & Research**
```clarity
(contract-call? .prediction-pool create-market
  u"Will a quantum computer break RSA-2048 by 2030?"
  u"YES if any organization successfully factors the RSA-2048 challenge number using a quantum computer, verified by independent cryptographers."
  u"Scientific journals and RSA challenge website"
  u262800  ;; ~5 years
  u4320    ;; 30 days to verify
  "science")
```

## 🏗️ Technical Architecture

### Core Data Structures

**Market Structure**
```clarity
{
  creator: principal,               // Market creator
  question: string-utf8 200,        // Question being predicted
  description: string-utf8 500,     // Detailed description
  resolution-source: string-utf8,   // Where to verify outcome
  deadline: uint,                   // When betting closes
  resolution-time: uint,            // When outcome should be set
  category: string-ascii 30,        // Market category
  yes-pool: uint,                   // Total STX on YES
  no-pool: uint,                    // Total STX on NO
  total-volume: uint,               // Cumulative betting volume
  status: string-ascii 20,          // active/resolved/cancelled
  outcome: optional bool,           // Final result (true=YES)
  created-at: uint,                 // Creation block
  resolved-at: optional uint,       // Resolution block
  resolver: optional principal      // Who resolved it
}
```

**Position Structure**
```clarity
{
  yes-amount: uint,                 // STX bet on YES
  no-amount: uint,                  // STX bet on NO
  yes-shares: uint,                 // YES position shares
  no-shares: uint,                  // NO position shares
  claimed: bool,                    // Payout claimed status
  total-invested: uint              // Total STX invested
}
```

**Market Statistics**
```clarity
{
  total-participants: uint,         // Unique participants
  yes-bettors: uint,                // Number betting YES
  no-bettors: uint,                 // Number betting NO
  largest-position: uint,           // Biggest single bet
  last-trade-price: uint            // Most recent price
}
```

## 📖 Complete Usage Guide

### For Market Creators

#### Step 1: Create Market
```clarity
(contract-call? .prediction-pool create-market
  u"Will ETH 2.0 staking exceed 50M ETH by year-end?"
  u"Market resolves YES if total ETH staked in Ethereum 2.0 contracts exceeds 50 million ETH at any point before Dec 31, 2025 23:59:59 UTC. Verified via official Ethereum Foundation data."
  u"Ethereum.org staking statistics"
  u26280                            ;; ~6 months until betting closes
  u1440                             ;; 10 days to resolve after close
  "crypto")
;; Returns: (ok u1) - your market ID
```

#### Step 2: Resolve Market (After Deadline)
```clarity
;; After deadline passes and you verify the outcome
(contract-call? .prediction-pool resolve-market
  u1                                ;; market ID
  true)                             ;; outcome: true = YES won, false = NO won
;; Returns: (ok true)
```

#### Optional: Cancel (Before Any Bets)
```clarity
;; Only works if no one has bet yet
(contract-call? .prediction-pool cancel-market u1)
```

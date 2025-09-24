# 🎨 CCRoyalties - Content Creator Royalties & IP Management

A revolutionary platform built on Stacks blockchain that empowers content creators to mint their work as NFTs with automatic royalty distribution to collaborators and previous owners. 💰✨

## 🚀 Features

- 🖼️ **NFT Minting**: Transform your creative work into unique digital assets
- 👥 **Collaborative Royalties**: Automatically distribute earnings to up to 10 collaborators
- 🔄 **Resale Royalties**: Creators earn on every resale forever
- 💸 **Transparent Payments**: All transactions are recorded on-chain
- 📊 **Earnings Tracking**: Monitor your accumulated royalties
- 🏪 **Built-in Marketplace**: List and trade your NFTs directly
- 🏆 **Creator Reputation System**: Build trust through verified sales and community engagement
- 📈 **Advanced Analytics**: Track performance metrics, sales trends, and creator insights
- 💰 **Smart Discounts**: Earn marketplace fee reductions based on reputation scores
- 🎖️ **Achievement System**: Unlock special badges and recognition for milestones

## 📋 Contract Functions

### 🎭 Core Functions

#### `mint-nft`
```clarity
(mint-nft title description metadata-uri royalty-percentage collaborators)
```
Mint a new NFT with embedded royalty structure.

**Parameters:**
- `title`: Your creation's title (max 256 chars)
- `description`: Detailed description (max 512 chars) 
- `metadata-uri`: URI to metadata/media file
- `royalty-percentage`: Creator royalty % (in basis points, max 5000 = 50%)
- `collaborators`: List of collaborators with their royalty percentages

#### `list-for-sale`
```clarity
(list-for-sale token-id price duration)
```
List your NFT for sale on the marketplace.

#### `buy-token`
```clarity
(buy-token token-id)
```
Purchase an NFT and automatically distribute royalties.

#### `transfer`
```clarity
(transfer token-id sender recipient)
```
Transfer NFT ownership between users.

### 💰 Financial Functions

#### `withdraw-earnings`
```clarity
(withdraw-earnings)
```
Withdraw accumulated royalty earnings.

#### `get-user-earnings`
```clarity
(get-user-earnings user)
```
Check total earnings for any user.

### 📖 Read-Only Functions

#### `get-token-metadata`
```clarity
(get-token-metadata token-id)
```
Retrieve complete NFT metadata.

#### `get-token-royalties`
```clarity
(get-token-royalties token-id)
```
View royalty structure for any NFT.

#### `get-token-history`
```clarity
(get-token-history token-id)
```
Get comprehensive NFT information including metadata, royalties, and current status.

## 🏆 Reputation & Analytics Functions

### 📊 Creator Analytics

#### `get-creator-stats`
```clarity
(get-creator-stats creator)
```
Retrieve detailed creator performance metrics.

**Returns:**
- `total-sales`: Number of successful NFT sales
- `total-revenue`: Cumulative revenue earned
- `average-price`: Average sale price across all NFTs
- `engagement-score`: Community engagement rating
- `first-sale-block`: Block height of first sale
- `last-activity-block`: Most recent activity
- `discount-earned`: Whether creator qualifies for fee discounts

#### `get-trust-score`
```clarity
(get-trust-score user)
```
Calculate combined creator and collector reputation score.

#### `qualifies-for-discount`
```clarity
(qualifies-for-discount user)
```
Check if user qualifies for reduced marketplace fees (5% discount at 5000+ reputation).

### 🎯 Community Engagement

#### `record-engagement`
```clarity
(record-engagement creator score)
```
Record community engagement for a creator (costs 0.001 STX to prevent spam).

**Parameters:**
- `creator`: Creator to rate
- `score`: Engagement score (0-1000)

#### `grant-achievement`
```clarity
(grant-achievement creator achievement)
```
Grant special achievement badge to creator (contract owner only).

### 📈 Platform Analytics

#### `get-platform-analytics`
```clarity
(get-platform-analytics)
```
Retrieve platform-wide statistics including total volume and creator count.

#### `get-creator-dashboard`
```clarity
(get-creator-dashboard creator)
```
Get comprehensive creator dashboard with stats, reputation, and achievements.

## 🛠️ Usage Examples

### Mint Your First NFT
```clarity
;; Simple NFT with 5% creator royalty
(contract-call? .CCRoyalties mint-nft 
  "Digital Sunset"
  "A beautiful digital sunset painting"
  "https://ipfs.io/ipfs/QmHash123"
  u500  ;; 5% royalty
  (list)) ;; No collaborators

;; NFT with collaborators
(contract-call? .CCRoyalties mint-nft
  "Epic Music Track"
  "Collaborative electronic music piece"
  "https://ipfs.io/ipfs/QmHash456"
  u300  ;; 3% creator royalty
  (list 
    {collaborator: 'SP2..., percentage: u200}  ;; 2% to collaborator
    {collaborator: 'SP3..., percentage: u100}  ;; 1% to another collaborator
  ))
```

### List for Sale
```clarity
;; List NFT #1 for 1000 STX, expires in 1000 blocks
(contract-call? .CCRoyalties list-for-sale u1 u1000000000 u1000)
```

### Purchase NFT
```clarity
;; Buy NFT #1 (royalties automatically distributed)
(contract-call? .CCRoyalties buy-token u1)
```


### Reputation & Analytics
```clarity
;; Check creator's reputation and stats
(contract-call? .CCRoyalties get-creator-stats 'SP1...)
(contract-call? .CCRoyalties get-trust-score 'SP1...)

;; Record community engagement (costs 0.001 STX)
(contract-call? .CCRoyalties record-engagement 'SP1... u750)

;; Check if user qualifies for discounts
(contract-call? .CCRoyalties qualifies-for-discount 'SP1...)

;; View creator dashboard
(contract-call? .CCRoyalties get-creator-dashboard 'SP1...)

;; Grant achievement (contract owner only)
(contract-call? .CCRoyalties grant-achievement 'SP1... u"Top Seller")
```

## 💡 Key Benefits

- 🎯 **Fair Compensation**: Ensures all contributors get paid automatically
- 🔒 **Immutable Rights**: Royalty agreements can't be changed after minting
- 🌐 **Global Reach**: Accessible to creators worldwide via Stacks blockchain
- 💎 **True Ownership**: Creators maintain IP rights while monetizing their work
- 💰 **Passive Income**: Earn royalties on every future sale
- 🏆 **Trust Building**: Build reputation through consistent sales and community engagement
- 📊 **Data-Driven Insights**: Make informed decisions with comprehensive analytics
- 👥 **Community Validation**: Peer-to-peer engagement scoring system
- 💰 **Performance Rewards**: Earn discounts and privileges based on reputation

## ⚙️ Technical Specifications

- **Platform Fee**: 2.5% (configurable by contract owner)
- **Maximum Royalties**: 50% total (creator + collaborators combined)
- **Maximum Collaborators**: 10 per NFT
- **Token Standard**: SIP-009 NFT compliant
- **Blockchain**: Stacks (Bitcoin security)

## 🎪 Getting Started

1. **Deploy Contract**: Deploy CCRoyalties.clar to Stacks mainnet/testnet
2. **Mint Content**: Use `mint-nft` to tokenize your creative work
3. **Set Royalties**: Define fair compensation for all contributors  
4. **List & Sell**: Use built-in marketplace functions
5. **Build Reputation**: Engage with community and earn trust scores
6. **Earn Forever**: Collect royalties on all future sales and unlock discounts! 🎉

## 🔐 Security Features

- Owner-only administrative functions
- Input validation for all parameters
- Safe math operations preventing overflow
- Comprehensive error handling
- Reentrancy protection

## 📄 License

This project is open source and available under the MIT License.

---

Built with ❤️ for the creator economy on Stacks blockchain 🔥

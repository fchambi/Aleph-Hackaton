# 🌱 PachaCredit

**PachaCredit** is an open infrastructure for **fair community microcredits in Latin America**.  
The protocol enables **community lending pools**, **small loans with simple interest**, and an **on-chain reputation score** that rewards responsible borrowers.  

---

## 🚀 Vision & Purpose

- **Financial inclusion**: Provide fair access to credit for unbanked and underbanked communities in LatAm.  
- **Transparency**: All rules are governed by smart contracts, with open and auditable transactions.  
- **Community-powered**: Local investors and cooperatives can create their own lending pools.  
- **Reputation-based**: Borrowers build an **on-chain credit score** that improves with good repayment behavior.  

---

## 🛠️ Technology Stack

- **Blockchain**: EVM-compatible (Lisk L2 / Ethereum testnets).  
- **Smart Contracts**: Solidity ^0.8.23 with OpenZeppelin libraries.  
- **Frameworks**: Hardhat + Hardhat Deploy.  
- **Frontend**: Next.js + TailwindCSS (Web3 dashboard style).  
- **Wallet Integration**: wagmi / viem.  

---

## 🏗️ Smart Contract Architecture

contracts/
├─ MicroCreditPoolFactory.sol # Creates and registers pools
├─ MicroCreditPool.sol # Core pool logic: deposits, loans, repayments
├─ LoanManager.sol # Loan lifecycle and debt calculation
├─ CreditScoreRegistry.sol # On-chain reputation system (0–100 score)
├─ Treasury.sol # Collects reserve fees from interest
├─ interfaces/ # Contract interfaces
└─ libs/Types.sol # Shared structs and enums

markdown
Copiar código

### 🔹 Contract Roles
- **DEFAULT_ADMIN_ROLE** → Deployers / System admins  
- **MANAGER_ROLE** → Approve loans, configure pool parameters  
- **POOL_ROLE** → LoanManager contract interacts with Registry & Treasury  
- **TREASURY_ADMIN_ROLE** → Controls treasury withdrawals  

### 🔹 Key Features
- **Pool Factory**: Create multiple pools with different parameters (interest, tenor, score requirement).  
- **MicroCredit Pool**: LPs deposit stablecoins, borrowers request & repay loans.  
- **Loan Manager**: Calculates debt with simple interest by days.  
- **Credit Score**: Reputation increases with repayment (+15) and decreases with defaults (-30).  
- **Treasury**: Receives a fraction of interest (`reserveFactor`) to sustain the protocol.  

---

## 📦 Deployment Report

👤 **Deployer**: `0xC5F38CF01f0C0af20DaEfE62ECDCC6311CfeB86c`

### **Step 1: Deploy MockStablecoin**
- Address: `0x1aa7d8045D18e3ed70103f32294a14E839D7Ce01`  
- Total Supply: 1,000,000,000,000 (decimals: 6)  

### **Step 2: Deploy CreditScoreRegistry**
- Address: `0x3E42fB1C4D04916e86b741049df219EB3D71ca82`  
- Roles: `DEFAULT_ADMIN_ROLE` → Deployer  

### **Step 3: Deploy Treasury**
- Address: `0xf7596AEAc4515350B100048Edc4F6FeB02F604Df`  
- Roles:  
  - `DEFAULT_ADMIN_ROLE` → Deployer  
  - `TREASURY_ADMIN_ROLE` → Deployer  

### **Step 4: Deploy LoanManager**
- Address: `0x75aaAad403b206db02B8bD0ea8E357D238Ae48f3`  


### **Step 5: Deploy MicroCreditPoolFactory**
- Address: `0xAD39Bd520B519b21Ed1dFE35B21d915c459E892E`  

### **Step 6: Example Pool**
- Address: `0x3B688fbF09DDf5432188B93c8Ece32f655b8278F`  
- Parameters: 5% interest, 90 days tenor, 50% max loan ratio, 20% reserve factor, 50 min score  

### **Step 7: Roles & Permissions**
- LoanManager granted `POOL_ROLE` in Registry, Treasury, LoanManager  
- Deployer granted `MANAGER_ROLE` in LoanManager  
- Deployer granted `TREASURY_ADMIN_ROLE` in Treasury  

### **Step 8: Real Pool**
- Address: `0x13b084665235CD3562d0C867035Fb3564c1B27Ec`  
- Parameters: 8% interest, 180 days tenor, 30% max loan ratio, 15% reserve factor, 70 min score  

---

## 🔍 Final System Verification

- **CreditScoreRegistry**: `0x3E42fB1C4D04916e86b741049df219EB3D71ca82`  
- **Treasury**: `0xf7596AEAc4515350B100048Edc4F6FeB02F604Df`  
- **LoanManager**: `0x75aaAad403b206db02B8bD0ea8E357D238Ae48f3`  
- **MicroCreditPoolFactory**: `0xAD39Bd520B519b21Ed1dFE35B21d915c459E892E`  
- **Example Pool**: `0xcf429Ae0e4B63512b37aA78D293c1C8984DD9226`  
- **Real Pool**: `0x13b084665235CD3562d0C867035Fb3564c1B27Ec`  
- **Total Pools Created**: 3  

✅ All roles correctly assigned  
✅ Pools ready to accept deposits and process loans  

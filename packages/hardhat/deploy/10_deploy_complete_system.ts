import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

/**
 * Deploys the complete MicroCredit DAO system
 * This script orchestrates the deployment of all contracts in the correct order
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployCompleteSystem: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
    This script deploys the entire MicroCredit DAO system in the correct order:
    1. CreditScoreRegistry
    2. Treasury
    3. LoanManager
    4. MicroCreditPoolFactory
    5. Setup roles and permissions
    6. Create example pool (optional)
  */
  const { deployer } = await hre.getNamedAccounts();
  const { deploy, get } = hre.deployments;

  console.log("🚀 Starting complete MicroCredit DAO deployment...");
  console.log("👤 Deployer:", deployer);

  try {
    // Step 1: Deploy MockStablecoin
    console.log("\n💵 Step 1: Deploying MockStablecoin...");
    await deploy("MockStablecoin", {
      from: deployer,
      args: ["Mock USDC", "mUSDC", 6], // 6 decimals like USDC
      log: true,
      autoMine: true,
    });
    const mockStablecoin = await hre.ethers.getContract<Contract>("MockStablecoin", deployer);
    console.log("✅ MockStablecoin deployed at:", await mockStablecoin.getAddress());

    // Step 2: Deploy CreditScoreRegistry
    console.log("\n📊 Step 2: Deploying CreditScoreRegistry...");
    await deploy("CreditScoreRegistry", {
      from: deployer,
      log: true,
      autoMine: true,
    });
    const creditScoreRegistry = await hre.ethers.getContract<Contract>("CreditScoreRegistry", deployer);
    console.log("✅ CreditScoreRegistry deployed at:", await creditScoreRegistry.getAddress());

    // Step 3: Deploy Treasury
    console.log("\n💰 Step 3: Deploying Treasury...");
    await deploy("Treasury", {
      from: deployer,
      log: true,
      autoMine: true,
    });
    const treasury = await hre.ethers.getContract<Contract>("Treasury", deployer);
    console.log("✅ Treasury deployed at:", await treasury.getAddress());

    // Step 4: Deploy LoanManager
    console.log("\n📋 Step 4: Deploying LoanManager...");
    await deploy("LoanManager", {
      from: deployer,
      log: true,
      autoMine: true,
    });
    const loanManager = await hre.ethers.getContract<Contract>("LoanManager", deployer);
    console.log("✅ LoanManager deployed at:", await loanManager.getAddress());

    // Step 5: Deploy MicroCreditPoolFactory
    console.log("\n🏭 Step 5: Deploying MicroCreditPoolFactory...");
    await deploy("MicroCreditPoolFactory", {
      from: deployer,
      log: true,
      autoMine: true,
    });
    const factory = await hre.ethers.getContract<Contract>("MicroCreditPoolFactory", deployer);
    console.log("✅ MicroCreditPoolFactory deployed at:", await factory.getAddress());

    // Step 6: Setup roles and permissions
    console.log("\n🔧 Step 6: Setting up roles and permissions...");
    
    // Grant POOL_ROLE to LoanManager in CreditScoreRegistry
    const tx1 = await creditScoreRegistry.grantPoolRole(await loanManager.getAddress());
    await tx1.wait();
    console.log("✅ POOL_ROLE granted to LoanManager in CreditScoreRegistry");

    // Grant POOL_ROLE to LoanManager in Treasury
    const tx2 = await treasury.grantPoolRole(await loanManager.getAddress());
    await tx2.wait();
    console.log("✅ POOL_ROLE granted to LoanManager in Treasury");

    // Grant POOL_ROLE to LoanManager in LoanManager (self)
    const tx3 = await loanManager.grantPoolRole(await loanManager.getAddress());
    await tx3.wait();
    console.log("✅ POOL_ROLE granted to LoanManager in LoanManager");

    // Grant MANAGER_ROLE to deployer in LoanManager
    const tx4 = await loanManager.grantRole(await loanManager.MANAGER_ROLE(), deployer);
    await tx4.wait();
    console.log("✅ MANAGER_ROLE granted to deployer in LoanManager");

    // Grant TREASURY_ADMIN_ROLE to deployer in Treasury
    const tx5 = await treasury.grantTreasuryAdminRole(deployer);
    await tx5.wait();
    console.log("✅ TREASURY_ADMIN_ROLE granted to deployer in Treasury");

    // Step 7: Create an example pool (optional - for testing)
    console.log("\n🏊 Step 7: Creating example pool for testing...");
    
    // Use the deployed mock stablecoin for testing
    const stablecoinAddress = await mockStablecoin.getAddress();
    
    const poolParams = {
      interestRateBps: 500,        // 5% annual simple interest
      tenorDays: 90,               // 90 days loan term
      maxLoanToPoolBps: 5000,      // Max 50% of pool assets per loan
      reserveFactorBps: 2000,      // 20% of interest goes to treasury
      minCreditScore: 50           // Minimum credit score required
    };

    const tx6 = await factory.createPool(
      stablecoinAddress,
      poolParams,
      "MicroCredit Test Pool",
      "MCTP"
    );
    await tx6.wait();
    
    const pools = await factory.getPools();
    const poolAddress = pools[pools.length - 1];
    console.log("✅ Example pool created at:", poolAddress);

    // Final verification
    console.log("\n🔍 Final system verification:");
    console.log("   CreditScoreRegistry:", await creditScoreRegistry.getAddress());
    console.log("   Treasury:", await treasury.getAddress());
    console.log("   LoanManager:", await loanManager.getAddress());
    console.log("   MicroCreditPoolFactory:", await factory.getAddress());
    console.log("   Example Pool:", poolAddress);
    console.log("   Total Pools Created:", await factory.getPoolCount());

    // Verify roles
    const loanManagerAddress = await loanManager.getAddress();
    console.log("\n🔑 Role verification:");
    console.log("   LoanManager has POOL_ROLE in CreditScoreRegistry:", 
      await creditScoreRegistry.hasRole(await creditScoreRegistry.POOL_ROLE(), loanManagerAddress));
    console.log("   LoanManager has POOL_ROLE in Treasury:", 
      await treasury.hasRole(await treasury.POOL_ROLE(), loanManagerAddress));
    console.log("   Deployer has MANAGER_ROLE in LoanManager:", 
      await loanManager.hasRole(await loanManager.MANAGER_ROLE(), deployer));
    console.log("   Deployer has TREASURY_ADMIN_ROLE in Treasury:", 
      await treasury.hasRole(await treasury.TREASURY_ADMIN_ROLE(), deployer));

    console.log("\n🎉 MicroCredit DAO system deployed successfully!");
    console.log("\n📚 Next steps:");
    console.log("   1. Replace mock stablecoin address with real one in production");
    console.log("   2. Customize pool parameters according to business needs");
    console.log("   3. Test the system with small amounts");
    console.log("   4. Deploy to mainnet when ready");

  } catch (error) {
    console.error("❌ Error deploying complete system:", error);
    throw error;
  }
};

export default deployCompleteSystem;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags CompleteSystem
deployCompleteSystem.tags = ["CompleteSystem"];

// This deploy function doesn't have dependencies as it handles everything internally
deployCompleteSystem.dependencies = [];

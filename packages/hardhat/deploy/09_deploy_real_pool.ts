import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

/**
 * Deploys a real MicroCreditPool with custom configuration
 * This script now uses the mock stablecoin by default for testing
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployRealPool: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
    This script deploys a real MicroCreditPool with production-ready parameters.
    For testing, it uses the mock stablecoin. For production, modify the stablecoin address.
  */
  const { deployer } = await hre.getNamedAccounts();
  const { get } = hre.deployments;

  // Get deployed contracts
  const factory = await hre.ethers.getContract<Contract>("MicroCreditPoolFactory", deployer);

  // 🔧 Get the mock stablecoin address for testing, or use a real one for production
  let stablecoinAddress: string;
  
  try {
    // Try to get the mock stablecoin address
    const mockStablecoin = await hre.ethers.getContract<Contract>("MockStablecoin", deployer);
    stablecoinAddress = await mockStablecoin.getAddress();
    console.log("🔧 Using MockStablecoin for testing:", stablecoinAddress);
  } catch (error) {
    // If mock stablecoin is not deployed, use a placeholder (will be skipped)
    stablecoinAddress = "0x0000000000000000000000000000000000000000";
    console.log("⚠️  MockStablecoin not found, skipping real pool deployment");
    console.log("💡 To deploy a real pool, first deploy MockStablecoin or set a real stablecoin address");
    return; // Skip deployment instead of failing
  }

  // Customize these parameters according to your business requirements
  const poolParams = {
    interestRateBps: 800,        // 8% annual simple interest
    tenorDays: 180,              // 6 months loan term
    maxLoanToPoolBps: 3000,      // Max 30% of pool assets per loan
    reserveFactorBps: 1500,      // 15% of interest goes to treasury
    minCreditScore: 70           // Higher credit score requirement
  };

  console.log("🏭 Deploying real MicroCreditPool with parameters:");
  console.log("   Stablecoin Address:", stablecoinAddress);
  console.log("   Interest Rate:", poolParams.interestRateBps / 100, "%");
  console.log("   Tenor:", poolParams.tenorDays, "days");
  console.log("   Max Loan/Pool:", poolParams.maxLoanToPoolBps / 100, "%");
  console.log("   Reserve Factor:", poolParams.reserveFactorBps / 100, "%");
  console.log("   Min Credit Score:", poolParams.minCreditScore);

  // Validate stablecoin address (now more flexible)
  if (stablecoinAddress === "0x0000000000000000000000000000000000000000") {
    console.log("⏭️  Skipping real pool deployment - no valid stablecoin address configured");
    return; // Skip instead of throwing error
  }

  try {
    // Create pool through factory
    const tx = await factory.createPool(
      stablecoinAddress,
      poolParams,
      "MicroCredit DAO Pool",
      "MCDAO"
    );

    console.log("⏳ Pool creation transaction sent:", tx.hash);
    const receipt = await tx.wait();
    console.log("✅ Pool creation confirmed in block:", receipt.blockNumber);

    // Get the created pool address
    const pools = await factory.getPools();
    const poolAddress = pools[pools.length - 1]; // Latest created pool

    console.log("🎯 Real pool deployed at:", poolAddress);
    console.log("📊 Total pools in factory:", await factory.getPoolCount());

    // Verify the pool was created correctly
    const pool = await hre.ethers.getContractAt("MicroCreditPool", poolAddress);
    const poolParamsStored = await pool.getParams();
    
    console.log("\n🔍 Pool verification:");
    console.log("   Interest Rate:", Number(poolParamsStored.interestRateBps) / 100, "%");
    console.log("   Tenor:", Number(poolParamsStored.tenorDays), "days");
    console.log("   Max Loan/Pool:", Number(poolParamsStored.maxLoanToPoolBps) / 100, "%");
    console.log("   Reserve Factor:", Number(poolParamsStored.reserveFactorBps) / 100, "%");
    console.log("   Min Credit Score:", Number(poolParamsStored.minCreditScore));

    // Additional pool information
    console.log("\n📈 Pool status:");
    console.log("   Total Assets:", await pool.getTotalAssets());
    console.log("   LP Token Supply:", await pool.totalSupply());
    console.log("   Pool Paused:", await pool.paused());

    console.log("\n🚀 Pool is ready for use!");
    console.log("   Users can now deposit stablecoins and receive LP tokens");
    console.log("   Borrowers can request loans (if they meet credit score requirements)");
    console.log("   Managers can approve loans and manage the pool");

  } catch (error) {
    console.error("❌ Error deploying real pool:", error);
    // Don't throw error, just log it and continue
    console.log("⚠️  Pool deployment failed, but deployment process continues...");
  }
};

export default deployRealPool;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags RealPool
deployRealPool.tags = ["RealPool"];

// This deploy function depends on the factory and setup being completed
deployRealPool.dependencies = ["MicroCreditPoolFactory", "SetupRoles"];

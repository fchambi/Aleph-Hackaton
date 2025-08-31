import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

/**
 * Sets up roles and permissions between deployed contracts
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const setupRolesAndPermissions: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
    This script configures the necessary roles and permissions between the deployed contracts
    to ensure they can interact with each other properly.
  */
  const { deployer } = await hre.getNamedAccounts();
  const { get } = hre.deployments;

  console.log("🔧 Setting up roles and permissions...");

  try {
    // Get deployed contracts
    const creditScoreRegistry = await hre.ethers.getContract<Contract>("CreditScoreRegistry", deployer);
    const treasury = await hre.ethers.getContract<Contract>("Treasury", deployer);
    const loanManager = await hre.ethers.getContract<Contract>("LoanManager", deployer);
    const factory = await hre.ethers.getContract<Contract>("MicroCreditPoolFactory", deployer);

    // 1. Grant POOL_ROLE to LoanManager in CreditScoreRegistry
    console.log("📊 Granting POOL_ROLE to LoanManager in CreditScoreRegistry...");
    const tx1 = await creditScoreRegistry.grantPoolRole(await loanManager.getAddress());
    await tx1.wait();
    console.log("✅ POOL_ROLE granted to LoanManager in CreditScoreRegistry");

    // 2. Grant POOL_ROLE to LoanManager in Treasury
    console.log("💰 Granting POOL_ROLE to LoanManager in Treasury...");
    const tx2 = await treasury.grantPoolRole(await loanManager.getAddress());
    await tx2.wait();
    console.log("✅ POOL_ROLE granted to LoanManager in Treasury");

    // 3. Grant POOL_ROLE to LoanManager in LoanManager (self)
    console.log("📋 Granting POOL_ROLE to LoanManager in LoanManager...");
    const tx3 = await loanManager.grantPoolRole(await loanManager.getAddress());
    await tx3.wait();
    console.log("✅ POOL_ROLE granted to LoanManager in LoanManager");

    // 4. Grant MANAGER_ROLE to deployer in LoanManager
    console.log("🔑 Granting MANAGER_ROLE to deployer in LoanManager...");
    const tx4 = await loanManager.grantRole(await loanManager.MANAGER_ROLE(), deployer);
    await tx4.wait();
    console.log("✅ MANAGER_ROLE granted to deployer in LoanManager");

    // 5. Grant TREASURY_ADMIN_ROLE to deployer in Treasury
    console.log("🔑 Granting TREASURY_ADMIN_ROLE to deployer in Treasury...");
    const tx5 = await treasury.grantTreasuryAdminRole(deployer);
    await tx5.wait();
    console.log("✅ TREASURY_ADMIN_ROLE granted to deployer in Treasury");

    console.log("🎉 All roles and permissions configured successfully!");

    // Verify the setup
    console.log("\n🔍 Verifying role configuration:");
    
    const loanManagerAddress = await loanManager.getAddress();
    console.log("   LoanManager has POOL_ROLE in CreditScoreRegistry:", 
      await creditScoreRegistry.hasRole(await creditScoreRegistry.POOL_ROLE(), loanManagerAddress));
    console.log("   LoanManager has POOL_ROLE in Treasury:", 
      await treasury.hasRole(await treasury.POOL_ROLE(), loanManagerAddress));
    console.log("   LoanManager has POOL_ROLE in LoanManager:", 
      await loanManager.hasRole(await loanManager.POOL_ROLE(), loanManagerAddress));
    console.log("   Deployer has MANAGER_ROLE in LoanManager:", 
      await loanManager.hasRole(await loanManager.MANAGER_ROLE(), deployer));
    console.log("   Deployer has TREASURY_ADMIN_ROLE in Treasury:", 
      await treasury.hasRole(await treasury.TREASURY_ADMIN_ROLE(), deployer));

  } catch (error) {
    console.error("❌ Error setting up roles and permissions:", error);
    throw error;
  }
};

export default setupRolesAndPermissions;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags SetupRoles
setupRolesAndPermissions.tags = ["SetupRoles"];

// This deploy function depends on all contracts being deployed first
setupRolesAndPermissions.dependencies = ["CreditScoreRegistry", "Treasury", "LoanManager", "MicroCreditPoolFactory"];

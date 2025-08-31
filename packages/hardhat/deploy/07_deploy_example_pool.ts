import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

/**
 * Deploys an example MicroCreditPool using the factory
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployExamplePool: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
    On localhost, the deployer account is the one that comes with Hardhat, which is already funded.

    When deploying to live networks (e.g `yarn deploy --network sepolia`), the deployer account
    should have sufficient balance to pay for the gas fees for contract creation.

    You can generate a random account with `yarn generate` which will fill DEPLOYER_PRIVATE_KEY
    with a random private key in the .env file (then used on hardhat.config.ts)
    You can run the `yarn account` command to check your balance in every network.
  */
  const { deployer } = await hre.getNamedAccounts();
  const { get } = hre.deployments;

  // Get deployed contracts
  const factory = await hre.ethers.getContract<Contract>("MicroCreditPoolFactory", deployer);
  const creditScoreRegistry = await hre.ethers.getContract<Contract>("CreditScoreRegistry", deployer);
  const treasury = await hre.ethers.getContract<Contract>("Treasury", deployer);
  const loanManager = await hre.ethers.getContract<Contract>("LoanManager", deployer);

  // Get the deployed mock stablecoin for testing
  const mockStablecoin = await hre.ethers.getContract<Contract>("MockStablecoin", deployer);
  const stablecoinAddress = await mockStablecoin.getAddress();

  // Example pool parameters
  const poolParams = {
    interestRateBps: 500,        // 5% annual simple interest
    tenorDays: 90,               // 90 days loan term
    maxLoanToPoolBps: 5000,      // Max 50% of pool assets per loan
    reserveFactorBps: 2000,      // 20% of interest goes to treasury
    minCreditScore: 50           // Minimum credit score required
  };

  console.log("🏭 Creating example pool with parameters:");
  console.log("   Interest Rate:", poolParams.interestRateBps / 100, "%");
  console.log("   Tenor:", poolParams.tenorDays, "days");
  console.log("   Max Loan/Pool:", poolParams.maxLoanToPoolBps / 100, "%");
  console.log("   Reserve Factor:", poolParams.reserveFactorBps / 100, "%");
  console.log("   Min Credit Score:", poolParams.minCreditScore);

      // Create pool through factory
    const tx = await factory.createPool(
      stablecoinAddress,
      poolParams,
      "MicroCredit LP Token",
      "MCLP"
    );

  console.log("⏳ Pool creation transaction sent:", tx.hash);
  await tx.wait();

  // Get the created pool address
  const pools = await factory.getPools();
  const poolAddress = pools[pools.length - 1]; // Latest created pool

  console.log("✅ Example pool created at:", poolAddress);
  console.log("📊 Total pools in factory:", await factory.getPoolCount());

  // Verify the pool was created correctly
  const pool = await hre.ethers.getContractAt("MicroCreditPool", poolAddress);
  const poolParamsStored = await pool.getParams();
  
  console.log("🔍 Pool verification:");
  console.log("   Interest Rate:", Number(poolParamsStored.interestRateBps) / 100, "%");
  console.log("   Tenor:", Number(poolParamsStored.tenorDays), "days");
  console.log("   Max Loan/Pool:", Number(poolParamsStored.maxLoanToPoolBps) / 100, "%");
  console.log("   Reserve Factor:", Number(poolParamsStored.reserveFactorBps) / 100, "%");
  console.log("   Min Credit Score:", Number(poolParamsStored.minCreditScore));
};

export default deployExamplePool;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags ExamplePool
deployExamplePool.tags = ["ExamplePool"];

// This deploy function depends on the factory and other contracts being deployed first
deployExamplePool.dependencies = ["MockStablecoin", "MicroCreditPoolFactory", "CreditScoreRegistry", "Treasury", "LoanManager"];

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

/**
 * Deploys a contract named "MockStablecoin" using the deployer account
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployMockStablecoin: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
    On localhost, the deployer account is the one that comes with Hardhat, which is already funded.

    When deploying to live networks (e.g `yarn deploy --network sepolia`), the deployer account
    should have sufficient balance to pay for the gas fees for contract creation.

    You can generate a random account with `yarn generate` which will fill DEPLOYER_PRIVATE_KEY
    with a random private key in the .env file (then used on hardhat.config.ts)
    You can run the `yarn account` command to check your balance in every network.
  */
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  await deploy("MockStablecoin", {
    from: deployer,
    // Contract constructor arguments
    args: ["Mock USDC", "mUSDC", 6], // 6 decimals like USDC
    log: true,
    // autoMine: can be passed to the deploy function to make the deployment process faster on local networks by
    // automatically mining the contract deployment transaction. There is no effect on live networks.
    autoMine: true,
  });

  // Get the deployed contract to interact with it after deploying.
  const mockStablecoin = await hre.ethers.getContract<Contract>("MockStablecoin", deployer);
  console.log("💵 MockStablecoin deployed at:", await mockStablecoin.getAddress());
  console.log("📊 Total supply:", await mockStablecoin.totalSupply());
  console.log("👤 Owner:", await mockStablecoin.owner());
  console.log("🔢 Decimals:", await mockStablecoin.decimals());
};

export default deployMockStablecoin;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags MockStablecoin
deployMockStablecoin.tags = ["MockStablecoin"];

import { ethers } from "hardhat";
import { hashEndpointWithScope } from "@selfxyz/core";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  
  const nonce = await ethers.provider.getTransactionCount(deployer.address);
  console.log("Account nonce:", nonce);
  
  const futureAddress = ethers.getCreateAddress({
    from: deployer.address,
    nonce: nonce
  });
  console.log("Calculated future contract address:", futureAddress);

  const identityVerificationHub = "0x3e2487a250e2A7b56c7ef5307Fb591Cc8C83623D";

  const scope = hashEndpointWithScope("https://f2a6-2a09-bac5-5907-323-00-50-7f.ngrok-free.app", 'Self-Denver-Birthday');
  const attestationId = 1n;

  const token = "0x96CFA0E76Bd15d99A1230CA3955be5E677B746a6";

  const olderThanEnabled = false;
  const olderThan = 18n;
  const forbiddenCountriesEnabled = false;
  const forbiddenCountriesListPacked = [0n, 0n, 0n, 0n] as [bigint, bigint, bigint, bigint];
  const ofacEnabled = [false, false, false] as [boolean, boolean, boolean];
  
  const SelfHappyBirthday = await ethers.getContractFactory("SelfHappyBirthday");

  console.log("Deploying SelfHappyBirthday...");
  const selfHappyBirthday = await SelfHappyBirthday.deploy(
    identityVerificationHub,
    scope,
    attestationId,
    token,
    olderThanEnabled,
    olderThan,
    forbiddenCountriesEnabled,
    forbiddenCountriesListPacked,
    ofacEnabled
  );
  
  await selfHappyBirthday.waitForDeployment();
  
  const deployedAddress = await selfHappyBirthday.getAddress();
  console.log("SelfHappyBirthday deployed to:", deployedAddress);
  
  console.log("To verify on Celoscan:");
  console.log(`npx hardhat verify --network celo ${deployedAddress} ${identityVerificationHub} ${scope} ${attestationId} ${token} ${olderThanEnabled} ${olderThan} ${forbiddenCountriesEnabled} "[${forbiddenCountriesListPacked.join(',')}]" "[${ofacEnabled.join(',')}]"`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
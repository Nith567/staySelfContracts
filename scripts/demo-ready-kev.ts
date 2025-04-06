import { ethers } from "hardhat";
import { hashEndpointWithScope, getPackedForbiddenCountries, countries } from "@selfxyz/core";

function formatBlockedCountries(countries: string[]): string[] {
    return countries
        .filter(country => country !== '\x00\x00\x00')
        .map(country => country.trim());
}

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

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "CELO");
  const identityVerificationHub = "0x3e2487a250e2A7b56c7ef5307Fb591Cc8C83623D";

  // Generate scope from endpoint
  const scope = hashEndpointWithScope("https://f2a6-2a09-bac5-5907-323-00-50-7f.ngrok-free.app", 'Self-Hotel-Booking');
  console.log("scope: ", scope);
  const attestationId = 1n;

  const token = "0x96CFA0E76Bd15d99A1230CA3955be5E677B746a6";
  

  const boysBedPrice = 1000000n; 
  const girlsBedPrice = 1200000n;
  // Bed numbers for boys and girls
  const boysBeds = [1, 3, 5, 7];
  const girlsBeds = [2, 4, 6, 8];

  // Country restrictions (blocking only North Korea and Pakistan)
  const forbiddenCountries = [
    countries.NORTH_KOREA,
    countries.PAKISTAN
  ];
  const packed = getPackedForbiddenCountries(forbiddenCountries);
  const forbiddenCountriesListPacked = [
    BigInt(packed[0]),
    BigInt(packed[1]),
    BigInt(packed[2]),
    BigInt(packed[3])
  ] as [bigint, bigint, bigint, bigint];
  console.log("forbidden: ", forbiddenCountriesListPacked);
  const forbiddenCountriesEnabled = true;

  // OFAC compliance settings
  const ofacEnabled = [true, true, true] as [boolean, boolean, boolean];
  
  // Add this at the start of main() to get more gas info
  const gasPrice = await ethers.provider.getFeeData();
  console.log("Current gas price:", ethers.formatUnits(gasPrice.gasPrice || 0, "gwei"), "gwei");

  console.log("Deploying HotelBooking...");
  const HotelBooking = await ethers.getContractFactory("HotelBooking");
  
  try {
    const hotelBooking = await HotelBooking.deploy(
      identityVerificationHub,
      scope,
      attestationId,
      token,
      boysBedPrice,
      girlsBedPrice,
      boysBeds,
      girlsBeds,
      forbiddenCountriesEnabled,
      forbiddenCountriesListPacked,
      ofacEnabled
    );
    
    await hotelBooking.waitForDeployment();
    
    const deployedAddress = await hotelBooking.getAddress();
    console.log("HotelBooking deployed to:", deployedAddress);

    console.log("\nChecking blocked countries...");
    const blockedCountries = await hotelBooking.getBlockedCountries();
    const formattedCountries = formatBlockedCountries(blockedCountries);
    console.log("Blocked countries:", formattedCountries);

    // Verify contract on Celoscan
    console.log("\nTo verify on Celoscan:");
    console.log(`npx hardhat verify --network celo ${deployedAddress} ${identityVerificationHub} ${scope} ${attestationId} ${token} ${boysBedPrice} ${girlsBedPrice} "[${boysBeds.join(',')}]" "[${girlsBeds.join(',')}]" ${forbiddenCountriesEnabled} "[${forbiddenCountriesListPacked.join(',')}]" "[${ofacEnabled.join(',')}]"`);
  } catch (error) {
    console.error("Deployment failed with error:", error);
    if (error) {
        console.error("Error data:", error);
    }
    if (error) {
        console.error("Error reason:", error);
    }
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
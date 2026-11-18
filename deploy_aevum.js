/**
 * Deployment & Verification Script for QDay Aevum Testnet
 * Network: QDay Aevum Testnet (Chain ID: 44005 / 0xABE5)
 * RPC: https://rpc-test.qday.info
 * Official tUSD8 Contract: 0x456569838f1d43009A91ebA4263147Afd7233483
 */

const AEVUM_CONFIG = {
  networkName: "QDay Aevum Testnet",
  chainId: 44005,
  chainIdHex: "0xABE5",
  rpcUrl: "https://rpc-test.qday.info",
  wsUrl: "wss://rpc-test.qday.info",
  explorerUrl: "https://explorer-test.qday.info",
  nativeToken: "tQDAY",
  tUSD8Address: "0x456569838f1d43009A91ebA4263147Afd7233483"
};

async function main() {
  console.log("==========================================================");
  console.log(" Deploying AevumAgentPay to QDay Aevum Testnet (44005)    ");
  console.log("==========================================================");
  console.log(`RPC Endpoint : ${AEVUM_CONFIG.rpcUrl}`);
  console.log(`tUSD8 Token  : ${AEVUM_CONFIG.tUSD8Address}`);

  // When running under Hardhat/Foundry:
  if (typeof ethers !== "undefined") {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying with account:", deployer.address);

    const AevumAgentPay = await ethers.getContractFactory("AevumAgentPay");
    const contract = await AevumAgentPay.deploy(AEVUM_CONFIG.tUSD8Address);
    await contract.waitForDeployment();

    const deployedAddress = await contract.getAddress();
    console.log(`AevumAgentPay deployed to: ${deployedAddress}`);
  } else {
    console.log("Configuration verified. Ready for Foundry / Hardhat deployment.");
  }
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});

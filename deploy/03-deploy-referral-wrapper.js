const { network, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../helper-hardhat-config")
const { verify } = require("../helper-hardhat-config")

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const args = []
  const referralWrapper = await deploy("ReferralWrapper", {
    from: deployer,
    args,
    log: true,
    waitConfirmations: 6,
    waitConfirmations: network.config.blockConfirmations || 1,
  })
  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...")
    await verify(referralWrapper.address, args)
  }
  log("--------------------------------")
}

module.exports.tags = ["all", "raffle"]

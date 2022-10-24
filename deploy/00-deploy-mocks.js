const { developmentChains } = require("../helper-hardhat-config")

const BASE_FEE = ethers.utils.parseEther("0.25") //0.25 link per request
const GAS_PRICE_LINK = 1e9 // link per gas (chain link nodes have to pay the gas to execute transaction)

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  const chainId = network.name
  const args = [BASE_FEE, GAS_PRICE_LINK]
  if (developmentChains.includes(network.name)) {
    log("Local network detected! Deploying mocks...")

    await deploy("VRFCoordinatorV2Mock", {
      from: deployer,
      log: true,
      args,
    })
    await deploy("USDCMOCK", {
      from: deployer,
      log: true,
      args: ["USDCMOCK", "USDCMOCK"],
    })
    await deploy("LAGGMOCK", {
      from: deployer,
      log: true,
      args: ["LAGGMOCK", "LAGGMOCK"],
    })
    await deploy("Color", {
      from: deployer,
      log: true,
      args: [],
    })
    log("Mocks Deployed")
    log("----------------------------------------")
  }
}

module.exports.tags = ["all", "mocks"]

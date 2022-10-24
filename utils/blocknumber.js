async function getBlockNumber(ethers) {
  const blockNumBefore = await ethers.provider.getBlockNumber()
  const blockBefore = await ethers.provider.getBlock(blockNumBefore)
  return blockBefore.timestamp
}

module.exports = {
  getBlockNumber,
}

const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { getBlockNumber } = require("../utils/blocknumber")

async function printBalance(address, key, erc20s) {
  console.log(
    `${key} balance:`,
    ethers.utils.formatEther((await ethers.provider.getBalance(address)).toString())
  )
  for (let i = 0; i < erc20s.length; i++) {
    const balance = await erc20s[i].balanceOf(address)
    console.log(`${key} balance:`, ethers.utils.formatEther(balance.toString()))
  }
}

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("InvestorSchedule", function () {
      let fundMe
      let mockV3Aggregator
      let usdcMock
      let laggMock
      let deployer
      let player
      let signers
      let referralWrapperWithSigner
      const sendValue = ethers.utils.parseEther("1")
      beforeEach(async () => {
        // const accounts = await ethers.getSigners()
        // deployer = accounts[0]
        const namedAccounts = await getNamedAccounts()
        console.log(namedAccounts)
        signers = await ethers.getSigners()
        deployer = namedAccounts.deployer
        player = signers[1] //namedAccounts.player
        await deployments.fixture(["all"])
        investorSchedule = await ethers.getContract("InvestorSchedule", deployer)
        referralWrapper = await ethers.getContract("ReferralWrapper", deployer)
        usdcMock = await ethers.getContract("USDCMOCK", deployer)
        laggMock = await ethers.getContract("LAGGMOCK", deployer)
        color = await ethers.getContract("Color", deployer)
        referralWrapperWithSigner = await referralWrapper.connect(player)
      })

      describe("referral wrapper", async () => {
        it("mints and sends fees appropriately", async () => {
          affiliate = deployer
          const fees = referralWrapper.whitelistTokens([usdcMock.address, laggMock.address])
          const transactionHash = await referralWrapper.deposit({
            value: ethers.utils.parseEther("500"),
          })
          const usdcMockTx = await usdcMock.mint(
            referralWrapper.address,
            ethers.utils.parseEther("500")
          )
          await usdcMockTx.wait()
          const laggMockTx = await laggMock.mint(
            referralWrapper.address,
            ethers.utils.parseEther("500")
          )
          await laggMockTx.wait()

          await transactionHash.wait()
          const feeTx = await referralWrapper.setFee(affiliate, [
            ethers.utils.parseEther("0.1"), // ETH
            ethers.utils.parseEther("0.1"), // USDC
            ethers.utils.parseEther("0.1"), // LAGG
          ])
          feeTx.wait()
          try {
            const mintTx = await referralWrapperWithSigner.mintNFT(affiliate, color.address, {
              value: ethers.utils.parseEther("1.0"),
            })
            const r = await mintTx.wait()
          } catch (e) {
            console.log(e)
          }

          await printBalance(affiliate, "affiliate", [usdcMock, laggMock])
          await printBalance(deployer, "deployer", [usdcMock, laggMock])
          await printBalance(player.address, "player", [usdcMock, laggMock])
          await printBalance(referralWrapper.address, "referral wrapper", [usdcMock, laggMock])

          const balancePlayer = await color.balanceOf(player.address)
          assert.equal("1", balancePlayer.toString(), "balance of player should be 1")
          const balanceContract = await color.balanceOf(referralWrapper.address)
          assert.equal("0", balanceContract.toString(), "balance of contract should be 0")
        })
      })

      xdescribe("fund", function () {
        // https://ethereum-waffle.readthedocs.io/en/latest/matchers.html
        // could also do assert.fail
        it("Fails if you don't send enough ETH", async () => {
          await expect(fundMe.fund()).to.be.revertedWith("You need to spend more ETH!")
        })
        // we could be even more precise here by making sure exactly $50 works
        // but this is good enough for now
        it("Updates the amount funded data structure", async () => {
          await fundMe.fund({ value: sendValue })
          const response = await fundMe.getAddressToAmountFunded(deployer)
          assert.equal(response.toString(), sendValue.toString())
        })
        it("Adds funder to array of funders", async () => {
          await fundMe.fund({ value: sendValue })
          const response = await fundMe.getFunder(0)
          assert.equal(response, deployer)
        })
      })
      xdescribe("withdraw", function () {
        beforeEach(async () => {
          await fundMe.fund({ value: sendValue })
        })
        it("withdraws ETH from a single funder", async () => {
          // Arrange
          const startingFundMeBalance = await fundMe.provider.getBalance(fundMe.address)
          const startingDeployerBalance = await fundMe.provider.getBalance(deployer)

          // Act
          const transactionResponse = await fundMe.withdraw()
          const transactionReceipt = await transactionResponse.wait()
          const { gasUsed, effectiveGasPrice } = transactionReceipt
          const gasCost = gasUsed.mul(effectiveGasPrice)

          const endingFundMeBalance = await fundMe.provider.getBalance(fundMe.address)
          const endingDeployerBalance = await fundMe.provider.getBalance(deployer)

          // Assert
          // Maybe clean up to understand the testing
          assert.equal(endingFundMeBalance, 0)
          assert.equal(
            startingFundMeBalance.add(startingDeployerBalance).toString(),
            endingDeployerBalance.add(gasCost).toString()
          )
        })
        // this test is overloaded. Ideally we'd split it into multiple tests
        // but for simplicity we left it as one
        it("is allows us to withdraw with multiple funders", async () => {
          // Arrange
          const accounts = await ethers.getSigners()
          for (i = 1; i < 6; i++) {
            const fundMeConnectedContract = await fundMe.connect(accounts[i])
            await fundMeConnectedContract.fund({ value: sendValue })
          }
          const startingFundMeBalance = await fundMe.provider.getBalance(fundMe.address)
          const startingDeployerBalance = await fundMe.provider.getBalance(deployer)

          // Act
          const transactionResponse = await fundMe.cheaperWithdraw()
          // Let's comapre gas costs :)
          // const transactionResponse = await fundMe.withdraw()
          const transactionReceipt = await transactionResponse.wait()
          const { gasUsed, effectiveGasPrice } = transactionReceipt
          const withdrawGasCost = gasUsed.mul(effectiveGasPrice)
          console.log(`GasCost: ${withdrawGasCost}`)
          console.log(`GasUsed: ${gasUsed}`)
          console.log(`GasPrice: ${effectiveGasPrice}`)
          const endingFundMeBalance = await fundMe.provider.getBalance(fundMe.address)
          const endingDeployerBalance = await fundMe.provider.getBalance(deployer)
          // Assert
          assert.equal(
            startingFundMeBalance.add(startingDeployerBalance).toString(),
            endingDeployerBalance.add(withdrawGasCost).toString()
          )
          // Make a getter for storage variables
          await expect(fundMe.getFunder(0)).to.be.reverted

          for (i = 1; i < 6; i++) {
            assert.equal(await fundMe.getAddressToAmountFunded(accounts[i].address), 0)
          }
        })
        it("Only allows the owner to withdraw", async function () {
          const accounts = await ethers.getSigners()
          const fundMeConnectedContract = await fundMe.connect(accounts[1])
          await expect(fundMeConnectedContract.withdraw()).to.be.revertedWith("FundMe__NotOwner")
        })
      })

      xdescribe("idk", function () {
        it("can create an account and show create account", async () => {
          const transferResponse = await erc20.mint(player.address, ethers.utils.parseEther("1"))
          await transferResponse.wait()
          const balance = await erc20.balanceOf(player.address)
          const timestamp = await getBlockNumber(ethers)
          const erc20WithSigner = await erc20.connect(player)
          const allowanceResponse = await erc20WithSigner.approve(
            investorSchedule.address,
            ethers.utils.parseEther("1")
          )
          allowanceResponse.wait()
          const investorScheduleWithSigner = await investorSchedule.connect(player)
          const response = await investorScheduleWithSigner.createAccount(
            erc20.address,
            ethers.utils.parseEther("1"),
            timestamp + 100
          )
          await response.wait()
          const investoor = await investorScheduleWithSigner.getInvestoor(player.address)
          console.log(investoor.token)
          assert.equal(investoor.token, erc20.address)
          assert.equal(investoor.balance.toString(), ethers.utils.parseEther("1").toString())
          assert.equal(investoor.startlock.toString(), (timestamp + 100).toString())
          assert.equal(investoor.endlock.toString(), (timestamp + 100 + 2).toString())
        })
      })
    })

import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("SaveAsset", function () {
  async function deploySaveAssetFixture() {
    // 1. Get Signers
    const [owner, otherAccount] = await ethers.getSigners();

    // 2. Deploy the SaveAsset Contract
    const SaveAsset = await ethers.getContractFactory("SaveAsset");
    const saveAsset = await SaveAsset.deploy();

    // 3. Deploy the Mock Token Contract
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const mockToken = await MockERC20.deploy();

    return { saveAsset, mockToken, owner, otherAccount };
  }

  describe("Ether Operations", function () {
    it("Should deposit Ether via function and update balance", async function () {
      const { saveAsset, owner } = await loadFixture(deploySaveAssetFixture);
      
      const depositAmount = ethers.parseEther("1.0");

      // Call depositEther with value
      await expect(saveAsset.depositEther({ value: depositAmount }))
        .to.emit(saveAsset, "EtherDeposited")
        .withArgs(owner.address, depositAmount);

      // Check User Balance in contract
      expect(await saveAsset.getEtherBalance(owner.address)).to.equal(depositAmount);
      
      // Check Contract's actual ETH balance
      expect(await saveAsset.getContractEtherBalance()).to.equal(depositAmount);
    });

    it("Should deposit Ether via receive (direct send) and update balance", async function () {
      const { saveAsset, owner } = await loadFixture(deploySaveAssetFixture);
      
      const depositAmount = ethers.parseEther("0.5");

      // Send ETH directly to contract address
      const tx = await owner.sendTransaction({
        to: await saveAsset.getAddress(),
        value: depositAmount,
      });
      await tx.wait();

      expect(await saveAsset.getEtherBalance(owner.address)).to.equal(depositAmount);
    });

    it("Should withdraw Ether and update balances", async function () {
      const { saveAsset, owner } = await loadFixture(deploySaveAssetFixture);
      const depositAmount = ethers.parseEther("2.0");
      const withdrawAmount = ethers.parseEther("1.0");

      // Deposit first
      await saveAsset.depositEther({ value: depositAmount });

      // Withdraw
      // We check that the contract balance decreases and the user balance increases
      await expect(saveAsset.withdrawEther(withdrawAmount))
        .to.changeEtherBalances(
          [owner, saveAsset],
          [withdrawAmount, -withdrawAmount]
        )
        .and.to.emit(saveAsset, "EtherWithdrawn")
        .withArgs(owner.address, withdrawAmount);

      // Check internal mapping updated
      expect(await saveAsset.getEtherBalance(owner.address)).to.equal(depositAmount - withdrawAmount);
    });

    it("Should revert if withdrawing more Ether than available", async function () {
      const { saveAsset } = await loadFixture(deploySaveAssetFixture);
      const amount = ethers.parseEther("1.0");

      await expect(saveAsset.withdrawEther(amount)).to.be.revertedWith(
        "Save: Insufficient Ether balance"
      );
    });
  });

  describe("ERC20 Token Operations", function () {
    it("Should deposit ERC20 tokens and update balance", async function () {
      const { saveAsset, mockToken, owner } = await loadFixture(deploySaveAssetFixture);
      
      const depositAmount = ethers.parseUnits("100", 18);

      // 1. Mint tokens to Owner so they have something to deposit
      await mockToken.mint(owner.address, depositAmount);

      // 2. APPROVE the SaveAsset contract to spend tokens
      await mockToken.approve(await saveAsset.getAddress(), depositAmount);

      // 3. Deposit
      await expect(saveAsset.depositToken(await mockToken.getAddress(), depositAmount))
        .to.emit(saveAsset, "TokenDeposited")
        .withArgs(owner.address, await mockToken.getAddress(), depositAmount);

      // 4. Check balances
      expect(await saveAsset.getTokenBalance(owner.address, await mockToken.getAddress()))
        .to.equal(depositAmount);
        
      expect(await saveAsset.getContractTokenBalance(await mockToken.getAddress()))
        .to.equal(depositAmount);
    });

    it("Should withdraw ERC20 tokens", async function () {
      const { saveAsset, mockToken, owner } = await loadFixture(deploySaveAssetFixture);
      const depositAmount = ethers.parseUnits("100", 18);
      const withdrawAmount = ethers.parseUnits("40", 18);

      // Setup: Mint -> Approve -> Deposit
      await mockToken.mint(owner.address, depositAmount);
      await mockToken.approve(await saveAsset.getAddress(), depositAmount);
      await saveAsset.depositToken(await mockToken.getAddress(), depositAmount);

      // Verify contract has the tokens before withdraw
      expect(await mockToken.balanceOf(await saveAsset.getAddress())).to.equal(depositAmount);

      // Withdraw
      await expect(saveAsset.withdrawToken(await mockToken.getAddress(), withdrawAmount))
        .to.emit(saveAsset, "TokenWithdrawn")
        .withArgs(owner.address, await mockToken.getAddress(), withdrawAmount);

      // Check internal mapping
      expect(await saveAsset.getTokenBalance(owner.address, await mockToken.getAddress()))
        .to.equal(depositAmount - withdrawAmount);

      // Check actual token balance on the token contract
      expect(await mockToken.balanceOf(await saveAsset.getAddress()))
        .to.equal(depositAmount - withdrawAmount);
        
      expect(await mockToken.balanceOf(owner.address))
        .to.equal(withdrawAmount);
    });

    it("Should revert if token transfer is not approved", async function () {
      const { saveAsset, mockToken, owner } = await loadFixture(deploySaveAssetFixture);
      const amount = ethers.parseUnits("100", 18);
      
      await mockToken.mint(owner.address, amount);

      // Try to deposit WITHOUT calling approve() first
      await expect(
        saveAsset.depositToken(await mockToken.getAddress(), amount)
      ).to.be.revertedWith("Allowance exceeded"); 
      // Note: Revert message depends on the MockToken implementation
    });

    it("Should revert if withdrawing more Tokens than available", async function () {
        const { saveAsset, mockToken } = await loadFixture(deploySaveAssetFixture);
        const amount = ethers.parseUnits("100", 18);
  
        await expect(
            saveAsset.withdrawToken(await mockToken.getAddress(), amount)
        ).to.be.revertedWith("Save: Insufficient token balance");
      });
  });
});
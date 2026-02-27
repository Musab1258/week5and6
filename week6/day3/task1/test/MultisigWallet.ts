import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";

describe("MultisigWallet", function() {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state, and reset to it in every test.
  async function deployMultisigWalletFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await hre.ethers.getSigners();

    const MultisigWallet = await hre.ethers.getContractFactory("MultisigWallet");
    const multisigWallet = await MultisigWallet.deploy([owner.address, otherAccount.address], 2) as any;

    return { multisigWallet, owner, otherAccount };
  }

  describe("Deployment", function() {
    it("Should set the right owners and threshold", async function() {
      const { multisigWallet, owner, otherAccount } = await loadFixture(deployMultisigWalletFixture);

      expect(await multisigWallet.owners(0)).to.equal(owner.address);
      expect(await multisigWallet.owners(1)).to.equal(otherAccount.address);
      expect(await multisigWallet.threshold()).to.equal(2);
    });
  });

  describe("Transactions", function() {
    it("Should allow owners to submit and confirm transactions", async function() {
      const { multisigWallet, owner, otherAccount } = await loadFixture(deployMultisigWalletFixture);

      // Submit a transaction
      await expect(multisigWallet.connect(owner).submitTransaction(otherAccount.address, 100, "0x"))
        .to.emit(multisigWallet, "SubmitTransaction")
        .withArgs(anyValue, otherAccount.address, 100);

      // Confirm the transaction
      await expect(multisigWallet.connect(otherAccount).confirmTransaction(0))
        .to.emit(multisigWallet, "ConfirmTransaction")
        .withArgs(anyValue, 0, otherAccount.address);
    });
  });

});
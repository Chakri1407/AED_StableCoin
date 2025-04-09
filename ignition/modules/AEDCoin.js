const { expect } = require("chai");

describe("AEDCoin", function () {
  let AEDCoin, aedCoin, owner, addr1;

  beforeEach(async function () {
    AEDCoin = await ethers.getContractFactory("AEDCoin");
    [owner, addr1] = await ethers.getSigners();
    aedCoin = await AEDCoin.deploy();
  });

  it("Should mint tokens only by owner", async function () {
    await aedCoin.mint(addr1.address, 1000);
    expect(await aedCoin.balanceOf(addr1.address)).to.equal(1000);

    await expect(aedCoin.connect(addr1).mint(addr1.address, 500))
      .to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Should burn tokens only by owner", async function () {
    await aedCoin.mint(addr1.address, 1000);
    await aedCoin.burn(addr1.address, 500);
    expect(await aedCoin.balanceOf(addr1.address)).to.equal(500);
  });
});

let Token = artifacts.require("./FulcrumToken.sol")
const { ether }  = require('./helpers/ether');
const { EVMRevert } = require('./helpers/EVMRevert.js')
const { increaseTimeTo, duration} = require('./helpers/increaseTime');
const { latestTime } = require('./helpers/latestTime');
const BigNumber  = require('bignumber.js');

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()

contract('Fulcrum ERC20 Token', async function(accounts) {
  describe('  Construct Fulcrum Token', async () => {
    const tokenPriceConst = ether(0.000001);
    const icoDurationConst = duration.days(30);

    let token;

    beforeEach(async () => {
      token = await Token.new(accounts[1], tokenPriceConst, icoDurationConst);
    });

    it('must correctly create the token.', async () => {
      const expectedTotalSupply = ether(400000000);
      const community = ether(250000000);
      const hardCap = ether(150000000);
     
      const totalSupply = await token.totalSupply();

      totalSupply.should.be.bignumber.equal(expectedTotalSupply);
      const balanceCommunity = await token.balanceOf(accounts[1]);

      const balanceHardCap = await token.balanceOf(token.address);
      balanceCommunity.should.be.bignumber.equal(community);
      balanceHardCap.should.be.bignumber.equal(hardCap);

      const icoDuration = await token.icoDuration();
      assert(icoDuration.toNumber() == icoDurationConst);

      const tokenPrice = await token.tokenPrice();
      tokenPrice.should.be.bignumber.equal(tokenPriceConst);
    });

    it('must accept eth and return FULC coin.', async () => {
      await token.sendTransaction({from: accounts[2], value: ether(0)}).should.be.rejectedWith(EVMRevert);
      await token.sendTransaction({from: accounts[2], value: ether(1)});
      const balance = await token.balanceOf(accounts[2]);
      const tokenPrice = await token.tokenPriceDiscount();
      balance.should.be.bignumber.equal(ether(1).mul(ether(1)).dividedToIntegerBy(tokenPrice));
    });

    it('must correctly change FULC price.', async () => {
      await token.setTokenPrice.sendTransaction(ether(0.000002), {from: accounts[0]});
      await token.setTokenPrice.sendTransaction(ether(0.000002), {from: accounts[1]}).should.be.rejectedWith(EVMRevert);
      await token.sendTransaction({from: accounts[2], value: ether(1)});
      const balance = await token.balanceOf(accounts[2]);
      const tokenPrice = await token.tokenPriceDiscount();
      (await token.tokenPrice()).should.be.bignumber.equal(ether(0.000002));
      balance.should.be.bignumber.equal(ether(1).mul(ether(1)).dividedToIntegerBy(tokenPrice));
    });

    it('must calculate correct discount #1', async () => {
      await token.sendTransaction({from: accounts[2], value: ether(0.1)});
      var balance = await token.balanceOf(accounts[2]);
      var tokenPrice = await token.tokenPrice();
      const startTimestamp = await token.startTimestamp();

      balance.should.be.bignumber.equal(ether(0.1).mul(ether(1)).dividedToIntegerBy(tokenPrice.mul(80).dividedToIntegerBy(100))); // 20% off

      await increaseTimeTo(startTimestamp.toNumber() + duration.days(1) + duration.seconds(1));
      await token.sendTransaction({from: accounts[3], value: ether(0.1)});
      balance = await token.balanceOf(accounts[3]);
      tokenPrice = await token.tokenPrice();
      balance.should.be.bignumber.equal(ether(0.1).mul(ether(1)).dividedToIntegerBy(tokenPrice.mul(85).dividedToIntegerBy(100))); //15 % off

      await increaseTimeTo(startTimestamp.toNumber() + duration.days(3) + duration.seconds(1));
      await token.sendTransaction({from: accounts[4], value: ether(0.1)});
      balance = await token.balanceOf(accounts[4]);
      tokenPrice = await token.tokenPrice();
      balance.should.be.bignumber.equal(ether(0.1).mul(ether(1)).dividedToIntegerBy(tokenPrice.mul(90).dividedToIntegerBy(100))); //10 % off

      await increaseTimeTo(startTimestamp.toNumber() + duration.days(5) + duration.seconds(1));
      await token.sendTransaction({from: accounts[5], value: ether(0.1)});
      balance = await token.balanceOf(accounts[5]);
      tokenPrice = await token.tokenPrice();
      balance.should.be.bignumber.equal(ether(0.1).mul(ether(1)).dividedToIntegerBy(tokenPrice)); //0 % off
    });

    it('must calculate correct discount #2', async () => {
      var tokenPrice = await token.tokenPrice();
      await token.calculateDiscount();
      const startTimestamp = await token.startTimestamp();
      var tokenPriceDiscount = await token.tokenPriceDiscount();
      tokenPriceDiscount.should.be.bignumber.equal(tokenPrice.mul(80).dividedToIntegerBy(100)); // 20% off

      await increaseTimeTo(startTimestamp.toNumber() + duration.days(1) + duration.seconds(1));
      await token.calculateDiscount();
      tokenPriceDiscount = await token.tokenPriceDiscount();
      tokenPriceDiscount.should.be.bignumber.equal(tokenPrice.mul(85).dividedToIntegerBy(100)); // 15% off

      await increaseTimeTo(startTimestamp.toNumber() + duration.days(3) + duration.seconds(1));
      await token.calculateDiscount();
      tokenPriceDiscount = await token.tokenPriceDiscount();
      tokenPriceDiscount.should.be.bignumber.equal(tokenPrice.mul(90).dividedToIntegerBy(100)); // 10% off

      await increaseTimeTo(startTimestamp.toNumber() + duration.days(5) + duration.seconds(1));
      await token.calculateDiscount();
      tokenPriceDiscount = await token.tokenPriceDiscount();
      tokenPriceDiscount.should.be.bignumber.equal(tokenPrice); // 0% off
    });

    it('must correctly end ICO #1', async () => { //ICO over, but soft cap not raised.
      const startTimestamp = await token.startTimestamp();
      await token.sendTransaction({from: accounts[0], value: ether(1)}); //soft cap
      await increaseTimeTo(startTimestamp.toNumber() + duration.days(30) + duration.seconds(1)); 
      await token.sendTransaction({from: accounts[0], value: ether(1)}).should.be.rejectedWith(EVMRevert);
    });
    it('must correctly end ICO #2', async () => { //soft cap reached but ICO is not over
      const startTimestamp = await token.startTimestamp();
      await token.sendTransaction({from: accounts[2], value: ether(1)}); //soft cap
      await token.sendTransaction({from: accounts[2], value: ether(1)});//no revert
      await increaseTimeTo(startTimestamp.toNumber() + duration.days(30) + duration.seconds(1)); //ICO end
      await token.sendTransaction({from: accounts[2], value: ether(1)}).should.be.rejectedWith(EVMRevert);
    });
    it('must correctly end ICO #3', async () => { //hard cap reached
      await token.sendTransaction({from: accounts[2], value: ether(90)});
      await token.sendTransaction({from: accounts[3], value: ether(90)}).should.be.rejectedWith(EVMRevert); //can't buy more
      await token.sendTransaction({from: accounts[3], value: ether(30)});
      await token.sendTransaction({from: accounts[3], value: ether(1)}).should.be.rejectedWith(EVMRevert); //ICO end
    });
    it('must correctly distribute coins after ICO', async () => {
      const startTimestamp = await token.startTimestamp();
      await token.sendTransaction({from: accounts[2], value: ether(1)}); //soft cap
      await token.sendTransaction({from: accounts[3], value: ether(2)}); 
      await token.sendTransaction({from: accounts[4], value: ether(2)});
      await increaseTimeTo(startTimestamp.toNumber() + duration.days(30) + duration.seconds(1));//ICO end
      const tokenLeft = await token.balanceOf(token.address);
      var balance2 = await token.balanceOf(accounts[2]);
      var balance3 = await token.balanceOf(accounts[3]);
      var balance4 = await token.balanceOf(accounts[4]);
      await token.distribute();
      await token.distribute().should.be.rejectedWith(EVMRevert); //deny double distribute
      
      (await token.balanceOf(accounts[2])).should.be.bignumber.equal(balance2.add(tokenLeft.mul(20).dividedToIntegerBy(100)));
      (await token.balanceOf(accounts[3])).should.be.bignumber.equal(balance3.add(tokenLeft.mul(40).dividedToIntegerBy(100)));
      (await token.balanceOf(accounts[4])).should.be.bignumber.equal(balance4.add(tokenLeft.mul(40).dividedToIntegerBy(100)));

    });
  });
});
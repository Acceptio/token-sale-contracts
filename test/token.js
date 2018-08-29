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
    it('must correctly create the token.', async () => {
      const expectedTotalSupply = ether(400000000);

      const token = await Token.new(accounts[1], 0.1, 90);
      const totalSupply = await token.totalSupply();

      totalSupply.should.be.bignumber.equal(expectedTotalSupply);
    });
  });
});
var Token = artifacts.require("./FulcrumToken.sol");

module.exports = function(deployer) {
  deployer.deploy(Token, "0xd028820281561e97fdf811ca777c3270c92da464", 1000000000000000000, 60000);
};

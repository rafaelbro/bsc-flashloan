const Arbitrage = artifacts.require("Arbitrage.sol");


module.exports = function (deployer) {
  deployer.deploy(
    Arbitrage,
    '0x6725F303b657a9451d8BA641348b6761A6CC7a17', //PancakeSwap factory
    '0x094616f0bdfb0b526bd735bf66eca0ad254ca81f', //BakerySwap router
  );

  /*
  module.exports = function (deployer) {
    deployer.deploy(
      Arbitrage,
      '0xBCfCcbde45cE874adCB698cC183deBcF17952812', //PancakeSwap factory
      'couldlt find their address :( if you try to trade with a liquidity pool on their website, metamask should show you the address of their router', //BakerySwap router
    );
  */
};

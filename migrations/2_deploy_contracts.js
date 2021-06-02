const Arbitrage = artifacts.require("Arbitrage.sol");


module.exports = function (deployer) {
  deployer.deploy(
    Arbitrage,
    '0xBCfCcbde45cE874adCB698cC183deBcF17952812', //PancakeSwap factory
    '0xF3feD705Db9974C6eEAa5cbE79FBe9BEb7D6F459', //BakerySwap router
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

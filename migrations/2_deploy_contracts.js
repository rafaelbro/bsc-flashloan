const Arbitrage = artifacts.require("Arbitrage.sol");


module.exports = function (deployer) {
  deployer.deploy(
    Arbitrage,
    '0xb7926c0430afb07aa7defde6da862ae0bde767bc', //PancakeSwap factory    
    ['0xCDe540d7eAFE93aC5fE6233Bee57E1270D3E330F'] //BakerySwap router
  );

  //0x6725F303b657a9451d8BA641348b6761A6CC7a17 -> 2nd factory pancake


};

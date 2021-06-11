const Arbitrage = artifacts.require("Arbitrage.sol");


module.exports = function (deployer) {
  deployer.deploy(
    Arbitrage,
    '0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73',
    [
      '0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F',
      '0x10ED43C718714eb63d5aA57B78B54704E256024E',
      '0xC0788A3aD43d79aa53B09c2EaCc313A787d1d607',
      '0xD48745E39BbED146eEC15b79cBF964884F9877c2',
      '0xCDe540d7eAFE93aC5fE6233Bee57E1270D3E330F',
      '0x7DAe51BD3E3376B8c7c4900E9107f12Be3AF1bA8',
      '0xb3F0C9ea1F05e312093Fdb031E789A756659B0AC',
      '0x191409D5A4EfFe25b0f4240557BA2192D18a191e',
      '0x160CAed03795365F3A589f10C379FfA7d75d4E76',
      '0xc6a752948627bECaB5474a10821Df73fF4771a49',
    ]
  );
// };


  //TESTNET DEPLOY
  // deployer.deploy(
  //   Arbitrage,
  //   '0xb7926c0430afb07aa7defde6da862ae0bde767bc', //PancakeSwap factory
  //   ['0xCDe540d7eAFE93aC5fE6233Bee57E1270D3E330F'] //BakerySwap router
  // );

  //0x6725F303b657a9451d8BA641348b6761A6CC7a17 -> 2nd factory pancake
  //'0xBCfCcbde45cE874adCB698cC183deBcF17952812', //PancakeSwap factory V1
}

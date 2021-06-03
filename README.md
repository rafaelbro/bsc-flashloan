# É o Arbitas
Environment Requirements:
- `Docker Desktop` installation in your local machine.
- Install `truffle` and `Ganache` in your local machine. Do it by running `npm install truffle -g` and `npm install ganache-cli -g`
- Install the `truffle/hdwallet-provider` via the command `npm install @truffle/hdwallet-provider`
- This repository cloned in your local machine
- Use VScode and `solidity` extension for conveniences

## Env Setup
### Prepare a new address and private key
1. Access [VANITY-ETH](https://vanity-eth.tk/) and generate a new address and private key. Store it in a place that you can get it latter.
2. Get BNB for the created address accessing the faucet for the [BsC Test net](https://testnet.binance.org/faucet-smart)
3. Validate the received BNB in the testnet by accessing https://testnet.bscscan.com/address/<ADDRESS_GENERATED>
4. In the `truffle-config.js` file, go to the `provider` creation and replace with the desired address

```
  const provider = new HDWalletProvider({
    privateKeys: ['961706d001210e16f60bcccb14c390f93deb97d3f89e37b58f50b3a7c16aa64a'],
    providerOrUrl: 'https://data-seed-prebsc-1-s1.binance.org:8545'
});
```

## Deploying the contract
1. Go to the root folder of the project, and enter `truffle compile`
2. Then, to deploy it, type `truffle migrate --reset --network testnet`. It will use the amount of BNB at the provided address and the address will be the owner of the contract.
3. Wait until it deploy it and then get the contract address after it successfully deploy it. Save it for later use.

## Interaction with the contract
1. Go to the truffle console by typing `truffle console --network testnet`
2. Instanciate the deployed contract by typing `let instance = await Arbitrage.deployed()` at the console.
3. Get the account address add to the truffle-config setup by calling `let accounts = await web3.eth.getAccounts()`. It will be the first address of the array, so you can get it by calling `accounts[0]`
4. Call the desired function or call with the necessary arguments. Remember that transactions spend some amount of gas, where calls does not use gas to get information from the network



## Alternative II
### Create a file .secret with the mnemonic phrase to walle
Use truffle and build project 
truffle build

### Migrate to network using
truffle migrate --network testnet

### Interact with testnet with 
truffle console --network testnet

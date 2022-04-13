/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * trufflesuite.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a private key for generating public key. If you're publishing your code to GitHub make sure you load this
 * key from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

const HDWalletProvider = require("@truffle/hdwallet-provider");
require("dotenv").config();

module.exports = {
  api_keys: {
    etherscan: process.env.ETHER_KEY,
  },

  plugins: ["truffle-plugin-verify"],
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

  networks: {
    // Ethereum mainnet...
    mainnet: {
      provider: () =>
        new HDWalletProvider(process.env.PRIVATE_KEY, process.env.API_KEY), //add private_key and rpc url
      network_id: 1, // Mainnet's id
    },

    // rinkeby
    rinkeby: {
      provider: () =>
        new HDWalletProvider(process.env.PRIVATE_KEY, process.env.API_KEY), //add private_key and rpc url
      network_id: 4, // Ropsten's id
    },

    // Binance Smart Chain
    bscTestnet: {
      provider: () =>
        new HDWalletProvider(
          process.env.PRIVATE_KEY,
          "https://data-seed-prebsc-1-s1.binance.org:8545/"
        ), //add private_key and rpc url
      network_id: 97, // BSC's id
    },

    // Binance Smart Chain
    bsc: {
      provider: () =>
        new HDWalletProvider(
          process.env.PRIVATE_KEY,
            "https://bsc-dataseed2.binance.org"
        ), //add private_key and rpc url
      network_id: 56, // BSC's id
    },

    // Mumbai
    mumbai: {
      provider: () =>
        new HDWalletProvider(
          process.env.PRIVATE_KEY,
          "https://polygon-mumbai.infura.io/v3/c847a9ffb72d45a2a1ee452b6f381bc1"
        ), //add private_key and rpc url
      network_id: 80001, // BSC's id
    },

    // Matic main
    matic: {
      provider: () =>
        new HDWalletProvider(
          process.env.PRIVATE_KEY,
            "https://polygon-mainnet.infura.io/v3/c847a9ffb72d45a2a1ee452b6f381bc1"
        ), //add private_key and rpc url
      network_id: 137, // BSC's id
    }

  },


  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.6", // Fetch exact version from solc-bin (default: truffle's version)
      settings: {
        // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },
};

/* global ethers task */
require('@nomiclabs/hardhat-waffle');
require('hardhat-contract-sizer');
require('dotenv').config();

const PV_KEY = process.env.PV_KEY;
//const API_KEY = process.env.API_KEY;

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
        version: '0.8.17',
      },
    ],
  },
  networks: {
    hardhat: {
      forking: {
        url: `https://rpc-mumbai.maticvigil.com`,
      },
    },
    // mumbai: {
    //   url: `https://rpc-mumbai.maticvigil.com`,
    //   accounts: [PV_KEY],
    // },
  },
};

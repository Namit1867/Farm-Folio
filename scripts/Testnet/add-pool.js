const { ethers } = require('hardhat');
const fs = require('fs');

const config = require('../../test/config.json');
const deploy = async () => {
  const accounts = await ethers.getSigners();
  const diamondAddress = '0xfda289b85B8ea9f3a8A358df7015a140244666aC';
  const portTokenAddress = '0xC063fE90B8Fc93ac5e18A2F2d0c51C71a26f5D5C';
  const farmFacet = await ethers.getContractAt('FarmFacet', diamondAddress);

  fs.mkdir('./build/deployments', { recursive: true }, (err) => {
    if (err) console.error(err);
  });

  const names = [
    'AUTO/BNB',
    'FIL/ETH',
    'BNB/USDC',
    'CAKE/USDT',
    'WLD/BAT',
    'GRT/ADA',
    'SOL/BTC',
    'ETH/ZSH',
    'BTC/XRP',
    'USDC/MATIC',
  ];

  for (let i = 1; i < names.length; i++) {
    const TOKEN = await ethers.getContractFactory('PORT');
    const token = await TOKEN.deploy(`${names[i]}`, `${names[i]}`);
    await token.deployed();
    //Deploy strategy
    let params = [
      config.wbnbAddress,
      accounts[0].address,
      diamondAddress,
      portTokenAddress,
      token.address,
      config.zeroAddress,
      accounts[0].address,
      config.buybackAddr,
    ];

    const STRATEGY = await ethers.getContractFactory('StratX2_AUTO');
    const strategy = await STRATEGY.connect(accounts[0]).deploy(params);
    await strategy.deployed();

    let tx = await farmFacet
      .connect(accounts[0])
      .add(config.allocPoint, token.address, false, strategy.address);
    await tx.wait();

    console.log(`deployed`);

    const address = token.address;
    const abi = JSON.parse(String(token.interface.format('json')));

    const output = {
      address,
      abi,
    };

    try {
      fs.writeFileSync(
        `./build/deployments/token${i}.json`,
        JSON.stringify(output, null, 2)
      );
    } catch (err) {
      console.log(err);
    }
  }
  console.log(`DONE`);
};

deploy();

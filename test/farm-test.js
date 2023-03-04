/* global describe it before ethers */

const {
    getSelectors,
    FacetCutAction,
    removeSelectors,
    findAddressPositionInFacets
  } = require('../scripts/libraries/diamond.js')
  
  const { deployDiamond, deployPORTToken } = require('../scripts/Testnet/deploy')
  
  const { assert, expect } = require('chai')
  const { ethers } = require('hardhat')
  const config = require('./config.json');

  function BigNumber(data) {
    return ethers.BigNumber.from(data);
  }

  async function getAddedShares(_wantAmt,strategy) {
    let sharesTotal = BigNumber(await strategy.sharesTotal());
    let entranceFeeFactor = BigNumber(await strategy.entranceFeeFactor());
    let wantLockedTotal = BigNumber(await strategy.wantLockedTotal());
    let entranceFeeFactorMax = BigNumber(await strategy.entranceFeeFactorMax());

    if (wantLockedTotal > 0 && sharesTotal > 0)
    return  BigNumber(_wantAmt)
                .mul(sharesTotal)
                .mul(entranceFeeFactor)
                .div(wantLockedTotal)
                .div(entranceFeeFactorMax);
    else
    return _wantAmt;
  }
  
  describe('Farm Test', async function () {
    let diamondAddress
    let diamondCutFacet
    let diamondLoupeFacet
    let ownershipFacet
    let farmFacet;
    let nftFacet;
    let strategy;
    let portToken;
    let startBlock;
    let tx;
    let receipt;
    let result;
    let accounts;
    const addresses = []
  
    before(async function () {
      accounts = await ethers.getSigners()
      //deploy PORT token
      portToken = await deployPORTToken();
      await portToken.mint(accounts[0].address,`1000${'0'.repeat(18)}`);
      startBlock = await ethers.provider.getBlockNumber();
      
      diamondAddress = await deployDiamond(portToken.address,startBlock);
      diamondCutFacet = await ethers.getContractAt('DiamondCutFacet', diamondAddress)
      diamondLoupeFacet = await ethers.getContractAt('DiamondLoupeFacet', diamondAddress)
      ownershipFacet = await ethers.getContractAt('OwnershipFacet', diamondAddress)
      farmFacet = await ethers.getContractAt('FarmFacet', diamondAddress)
      nftFacet = await ethers.getContractAt('NFTFacet', diamondAddress)

      await portToken.transferOwnership(diamondAddress);
    })
  
    it('should have five facets -- call to facetAddresses function', async () => {
      for (const address of await diamondLoupeFacet.facetAddresses()) {
        addresses.push(address)
      }
  
      assert.equal(addresses.length, 5)
    })
  
    it('facets should have the right function selectors -- call to facetFunctionSelectors function', async () => {
      let selectors = getSelectors(diamondCutFacet)
      result = await diamondLoupeFacet.facetFunctionSelectors(addresses[0])
      assert.sameMembers(result, selectors)
      selectors = getSelectors(diamondLoupeFacet)
      result = await diamondLoupeFacet.facetFunctionSelectors(addresses[1])
      assert.sameMembers(result, selectors)
      selectors = getSelectors(ownershipFacet)
      result = await diamondLoupeFacet.facetFunctionSelectors(addresses[2])
      assert.sameMembers(result, selectors)
      selectors = getSelectors(farmFacet)
      result = await diamondLoupeFacet.facetFunctionSelectors(addresses[3])
      assert.sameMembers(result, selectors)
      selectors = getSelectors(nftFacet)
      result = await diamondLoupeFacet.facetFunctionSelectors(addresses[4])
      assert.sameMembers(result, selectors)
    });

    //Using Pool0
    describe('TEST DEPOSIT', () => {

        it('DEPLOY STRATEGY', async() => {

          //Deploy strategy
          let params = [
            config.wbnbAddress,
            accounts[0].address,
            diamondAddress,
            portToken.address,
            portToken.address,
            config.zeroAddress,
            accounts[0].address,
            config.buybackAddr
          ];

          const STRATEGY = await ethers.getContractFactory('StratX2_AUTO');
          strategy = await STRATEGY.connect(accounts[0]).deploy(params)
          await strategy.deployed()

        });

        it("ADD POOL : Revert with `LibDiamond: Must be contract owner`", async() => {
          let tx = farmFacet.connect(accounts[1]).add(config.allocPoint,portToken.address,false,strategy.address)
          await expect(tx).to.be.revertedWith("LibDiamond: Must be contract owner");
          //console.log(strategy.address);
        })

        it("ADD POOL : Success", async() => {
          let totalAllocPointPrev = parseInt(await farmFacet.totalAllocPoint());
          await farmFacet.connect(accounts[0]).add(config.allocPoint,portToken.address,false,strategy.address)
          let totalAllocPointCurr = parseInt(await farmFacet.totalAllocPoint());
          expect(totalAllocPointPrev+config.allocPoint).to.equal(totalAllocPointCurr);
        })

        it("DEPOSIT INTO POOL", async() => {
          await portToken.approve(diamondAddress,`10${'0'.repeat(18)}`);
          let result = await getAddedShares(`10${'0'.repeat(18)}`,strategy);
          await farmFacet.deposit(0,`10${'0'.repeat(18)}`,0,true);
          let currNFTId = parseInt(await nftFacet.totalSupply()) - 1;
          
          //check initial owner is set
          let initialOwner = await nftFacet.initialOwner(currNFTId);
          expect(initialOwner).to.equal(accounts[0].address);

          let nftInfo = await farmFacet.nftInfo(0,currNFTId);
          expect(nftInfo.shares).to.equal(result);
        })

        it("DEPOSIT INTO POOL USING PRE OWNED NFT", async() => {
          await portToken.approve(diamondAddress,`10${'0'.repeat(18)}`);
          let currNFTId = parseInt(await nftFacet.totalSupply()) - 1;
          let preInfo = await farmFacet.nftInfo(0,currNFTId);
          let result = await getAddedShares(`10${'0'.repeat(18)}`,strategy);
          await farmFacet.deposit(0,`10${'0'.repeat(18)}`,0,false);
        
          let nftInfo = await farmFacet.nftInfo(0,currNFTId);
          expect(nftInfo.shares).to.equal(BigNumber(preInfo.shares).add(result));
        })

    });

    //Using Pool1
    describe('TEST WITHDRAW', () => {

      it('DEPLOY STRATEGY', async() => {

        //Deploy strategy
        let params = [
          config.wbnbAddress,
          accounts[0].address,
          diamondAddress,
          portToken.address,
          portToken.address,
          config.zeroAddress,
          accounts[0].address,
          config.buybackAddr
        ];

        const STRATEGY = await ethers.getContractFactory('StratX2_AUTO');
        strategy = await STRATEGY.connect(accounts[0]).deploy(params)
        await strategy.deployed()

      });

      it("ADD POOL : Revert with `LibDiamond: Must be contract owner`", async() => {
        let tx = farmFacet.connect(accounts[1]).add(config.allocPoint,portToken.address,false,strategy.address)
        await expect(tx).to.be.revertedWith("LibDiamond: Must be contract owner");
        //console.log(strategy.address);
      })

      it("ADD POOL : Success", async() => {
        let totalAllocPointPrev = parseInt(await farmFacet.totalAllocPoint());
        await farmFacet.connect(accounts[0]).add(config.allocPoint,portToken.address,false,strategy.address)
        let totalAllocPointCurr = parseInt(await farmFacet.totalAllocPoint());
        expect(totalAllocPointPrev+config.allocPoint).to.equal(totalAllocPointCurr);
      })

      it("DEPOSIT INTO POOL", async() => {
        let poolId = parseInt(await farmFacet.poolLength()) - 1;
        await portToken.approve(diamondAddress,`10${'0'.repeat(18)}`);
        await farmFacet.deposit(poolId,`10${'0'.repeat(18)}`,0,true);
        let currNFTId = parseInt(await nftFacet.totalSupply()) - 1;
        
        //check initial owner is set
        let initialOwner = await nftFacet.initialOwner(currNFTId);
        expect(initialOwner).to.equal(accounts[0].address);

        let nftInfo = await farmFacet.nftInfo(poolId,currNFTId);
        expect(nftInfo.shares).to.equal(`10${'0'.repeat(18)}`);
      })

      it("DEPOSIT INTO POOL", async() => {
        await portToken.approve(diamondAddress,`10${'0'.repeat(18)}`);
        let poolInfo = await farmFacet.poolInfo(0);
        strategy = await ethers.getContractAt("StratX2_AUTO",poolInfo.strat);
        let result = await getAddedShares(`10${'0'.repeat(18)}`,strategy);
        await farmFacet.deposit(0,`10${'0'.repeat(18)}`,1,false);
        
        let nftInfo = await farmFacet.nftInfo(0,1);
        expect(nftInfo.shares).to.equal(result);
      })

      // it("WITHDRAWS INTO POOL", async() => {
      //   let poolId = parseInt(await farmFacet.poolLength()) - 1;
      //   let currNFTId = parseInt(await nftFacet.totalSupply()) - 1;
      //   let nftInfo = await farmFacet.nftInfo(poolId,currNFTId);
        
      //   await farmFacet.withdraw(poolId,nftInfo.shares,currNFTId);
        
      //   //check initial owner is set
      //   let initialOwner = await nftFacet.initialOwner(currNFTId);
      //   expect(initialOwner).to.equal(accounts[0].address);

      //   nftInfo = await farmFacet.nftInfo(poolId,currNFTId);
      //   expect(nftInfo.shares).to.equal(`0`);
      // })

    });

    //Using Pool0 and Pool1 
    describe('TEST MERGE', () => {

      it("CALL MERGE", async() => {
       
        console.log("OLD PORTFOLIO:----")
        let nftInfo = await farmFacet.nftInfo(0,0);
        console.log(`POOL ID:- 0 , NFT ID 0`,nftInfo.shares);
        nftInfo = await farmFacet.nftInfo(0,1);
        console.log(`POOL ID:- 0 , NFT ID 1`,nftInfo.shares);
        nftInfo = await farmFacet.nftInfo(1,1);
        console.log(`POOL ID:- 1 , NFT ID 1`,nftInfo.shares);

        await farmFacet.mergePortfolios([0,1],[[0],[0,1]]);

        console.log("NEW PORTFOLIO:----")
        let currNFTId = parseInt(await nftFacet.currId()) - 1; 
        nftInfo = await farmFacet.nftInfo(0,currNFTId);
        console.log(`POOL ID:- 0 , NFT ID 2`,nftInfo.shares);
        nftInfo = await farmFacet.nftInfo(1,currNFTId);
        console.log(`POOL ID:- 1 , NFT ID 2`,nftInfo.shares);
      })

    });

    describe('TEST UNMERGE', () => {

      it("CALL UNMERGE", async() => {

        let currNFTId = parseInt(await nftFacet.currId()) - 1; 

        expect(await farmFacet.noOfPoolsInvested(currNFTId)).to.equal(2);

        console.log("------------------------BEFORE----------------------------")
       
        console.log("OLD PORTFOLIO:----")
        let nftInfo = await farmFacet.nftInfo(0,currNFTId);
        console.log(`POOL ID:- 0 , NFT ID 2`,nftInfo.shares);
        nftInfo = await farmFacet.nftInfo(1,currNFTId);
        console.log(`POOL ID:- 1 , NFT ID 2`,nftInfo.shares);
        
      
        await farmFacet.unmergePortfolios(currNFTId,[0]);

        expect(await farmFacet.noOfPoolsInvested(currNFTId)).to.equal(1);

        console.log("------------------------AFTER----------------------------")

        console.log("OLD PORTFOLIO:----")
        nftInfo = await farmFacet.nftInfo(0,currNFTId);
        console.log(`POOL ID:- 0 , NFT ID 2`,nftInfo.shares);
        nftInfo = await farmFacet.nftInfo(1,currNFTId);
        console.log(`POOL ID:- 1 , NFT ID 2`,nftInfo.shares);

        currNFTId = parseInt(await nftFacet.currId()) - 1; 

        expect(await farmFacet.noOfPoolsInvested(currNFTId)).to.equal(1);

        console.log("NEW PORTFOLIO:----")
        nftInfo = await farmFacet.nftInfo(0,currNFTId);
        console.log(`POOL ID:- 0 , NFT ID 3`,nftInfo.shares);
        nftInfo = await farmFacet.nftInfo(1,currNFTId);
        console.log(`POOL ID:- 1 , NFT ID 3`,nftInfo.shares);
      })

    });
  
    // it('selectors should be associated to facets correctly -- multiple calls to facetAddress function', async () => {
    //   assert.equal(
    //     addresses[0],
    //     await diamondLoupeFacet.facetAddress('0x1f931c1c')
    //   )
    //   assert.equal(
    //     addresses[1],
    //     await diamondLoupeFacet.facetAddress('0xcdffacc6')
    //   )
    //   assert.equal(
    //     addresses[1],
    //     await diamondLoupeFacet.facetAddress('0x01ffc9a7')
    //   )
    //   assert.equal(
    //     addresses[2],
    //     await diamondLoupeFacet.facetAddress('0xf2fde38b')
    //   )
    // })
  
    // it('should add AdditionFacet functions', async () => {
      
    //   const AdditionFacet = await ethers.getContractFactory('AdditionFacet')
    //   const additionFacet = await AdditionFacet.deploy()
    //   await additionFacet.deployed()
    //   addresses.push(additionFacet.address)
    //   const selectors = getSelectors(additionFacet).remove(['getDoubleDataA()'])
    //   tx = await diamondCutFacet.diamondCut(
    //     [{
    //       facetAddress: additionFacet.address,
    //       action: FacetCutAction.Add,
    //       functionSelectors: selectors
    //     }],
    //     ethers.constants.AddressZero, '0x', { gasLimit: 800000 })
    //   receipt = await tx.wait()
    //   if (!receipt.status) {
    //     throw Error(`Diamond upgrade failed: ${tx.hash}`)
    //   }
    //   result = await diamondLoupeFacet.facetFunctionSelectors(additionFacet.address)
    //   assert.sameMembers(result, selectors)
    // })
  
    // it('should test Addition Facet function call', async () => {
    //   const additionFacet = await ethers.getContractAt('AdditionFacet', diamondAddress);
    //   await additionFacet.setDataA(1);
    //   assert.equal(1,await additionFacet.getDataA());
    // })
  
    // it('should add `getDoubleDataA` function in AdditionFacet', async () => {
    //   const additionFacet = await ethers.getContractAt('AdditionFacet', diamondAddress);
    //   const AdditionFacet = await ethers.getContractFactory('AdditionFacet');
    //   const functionsToKeep = await diamondLoupeFacet.facetFunctionSelectors(addresses[3]);
    //   const selectors = getSelectors(AdditionFacet).remove(functionsToKeep);
    //   tx = await diamondCutFacet.diamondCut(
    //   [{
    //     facetAddress: addresses[3],
    //     action: FacetCutAction.Add,
    //     functionSelectors: selectors
    //   }],
    //   ethers.constants.AddressZero, '0x', { gasLimit: 800000 })
    //   receipt = await tx.wait()
    //   if (!receipt.status) {
    //     throw Error(`Diamond upgrade failed: ${tx.hash}`)
    //   }
    //   result = await diamondLoupeFacet.facetFunctionSelectors(addresses[3])
    //   assert.sameMembers(result, getSelectors(additionFacet))
    //   assert.equal(1,await additionFacet.getDataA());
    //   assert.equal(2*(await additionFacet.getDataA()),await additionFacet.getDoubleDataA());
    // })
  
    // it('should test Addition Facet function call', async () => {
    //   const additionFacet = await ethers.getContractAt('AdditionFacet', diamondAddress);
    //   assert.equal(2*(await additionFacet.getDataA()),await additionFacet.getDoubleDataA());
    // })
  
    // it('should add test1 functions', async () => {
    //   const Test1Facet = await ethers.getContractFactory('Test1Facet')
    //   const test1Facet = await Test1Facet.deploy()
    //   await test1Facet.deployed()
    //   addresses.push(test1Facet.address)
    //   const selectors = getSelectors(test1Facet)
    //   tx = await diamondCutFacet.diamondCut(
    //     [{
    //       facetAddress: test1Facet.address,
    //       action: FacetCutAction.Add,
    //       functionSelectors: selectors
    //     }],
    //     ethers.constants.AddressZero, '0x', { gasLimit: 800000 })
    //   receipt = await tx.wait()
    //   if (!receipt.status) {
    //     throw Error(`Diamond upgrade failed: ${tx.hash}`)
    //   }
    //   result = await diamondLoupeFacet.facetFunctionSelectors(test1Facet.address)
    //   assert.sameMembers(result, selectors)
    // })
  
    // it('should test Addition Facet function call', async () => {
    //   const test1Facet = await ethers.getContractAt('Test1Facet', diamondAddress);
    //   const additionFacet = await ethers.getContractAt('AdditionFacet', diamondAddress);
    //   await test1Facet.setData(2);
    //   await test1Facet.setDiamondAddress(diamondAddress)
    //   console.log(Number(await test1Facet.getTestData()))
    //   assert.equal(2,await test1Facet.getData());
    //   assert.equal(1,Number(await additionFacet.getDataA()));
    //   assert.equal(1,Number(await test1Facet.getAdditionFacteData()));
    // })
  
    // it('should test function call', async () => {
    //   const test1Facet = await ethers.getContractAt('Test1Facet', diamondAddress)
    //   await test1Facet.test1Func10()
    // })
  
    // it('should replace supportsInterface function', async () => {
    //   const Test1Facet = await ethers.getContractFactory('Test1Facet')
    //   const selectors = getSelectors(Test1Facet).get(['supportsInterface(bytes4)'])
    //   const testFacetAddress = addresses[3]
    //   tx = await diamondCutFacet.diamondCut(
    //     [{
    //       facetAddress: testFacetAddress,
    //       action: FacetCutAction.Replace,
    //       functionSelectors: selectors
    //     }],
    //     ethers.constants.AddressZero, '0x', { gasLimit: 800000 })
    //   receipt = await tx.wait()
    //   if (!receipt.status) {
    //     throw Error(`Diamond upgrade failed: ${tx.hash}`)
    //   }
    //   result = await diamondLoupeFacet.facetFunctionSelectors(testFacetAddress)
    //   assert.sameMembers(result, getSelectors(Test1Facet))
    // })
  
    // it('should add test2 functions', async () => {
    //   const Test2Facet = await ethers.getContractFactory('Test2Facet')
    //   const test2Facet = await Test2Facet.deploy()
    //   await test2Facet.deployed()
    //   addresses.push(test2Facet.address)
    //   const selectors = getSelectors(test2Facet)
    //   tx = await diamondCutFacet.diamondCut(
    //     [{
    //       facetAddress: test2Facet.address,
    //       action: FacetCutAction.Add,
    //       functionSelectors: selectors
    //     }],
    //     ethers.constants.AddressZero, '0x', { gasLimit: 800000 })
    //   receipt = await tx.wait()
    //   if (!receipt.status) {
    //     throw Error(`Diamond upgrade failed: ${tx.hash}`)
    //   }
    //   result = await diamondLoupeFacet.facetFunctionSelectors(test2Facet.address)
    //   assert.sameMembers(result, selectors)
    // })
  
    // it('should remove some test2 functions', async () => {
    //   const test2Facet = await ethers.getContractAt('Test2Facet', diamondAddress)
    //   const functionsToKeep = ['test2Func1()', 'test2Func5()', 'test2Func6()', 'test2Func19()', 'test2Func20()']
    //   const selectors = getSelectors(test2Facet).remove(functionsToKeep)
    //   tx = await diamondCutFacet.diamondCut(
    //     [{
    //       facetAddress: ethers.constants.AddressZero,
    //       action: FacetCutAction.Remove,
    //       functionSelectors: selectors
    //     }],
    //     ethers.constants.AddressZero, '0x', { gasLimit: 800000 })
    //   receipt = await tx.wait()
    //   if (!receipt.status) {
    //     throw Error(`Diamond upgrade failed: ${tx.hash}`)
    //   }
    //   result = await diamondLoupeFacet.facetFunctionSelectors(addresses[4])
    //   assert.sameMembers(result, getSelectors(test2Facet).get(functionsToKeep))
    // })
  
    // it('should remove some test1 functions', async () => {
    //   const test1Facet = await ethers.getContractAt('Test1Facet', diamondAddress)
    //   const functionsToKeep = ['test1Func2()', 'test1Func11()', 'test1Func12()']
    //   const selectors = getSelectors(test1Facet).remove(functionsToKeep)
    //   tx = await diamondCutFacet.diamondCut(
    //     [{
    //       facetAddress: ethers.constants.AddressZero,
    //       action: FacetCutAction.Remove,
    //       functionSelectors: selectors
    //     }],
    //     ethers.constants.AddressZero, '0x', { gasLimit: 800000 })
    //   receipt = await tx.wait()
    //   if (!receipt.status) {
    //     throw Error(`Diamond upgrade failed: ${tx.hash}`)
    //   }
    //   result = await diamondLoupeFacet.facetFunctionSelectors(addresses[3])
    //   assert.sameMembers(result, getSelectors(test1Facet).get(functionsToKeep))
    // })
  
    // it('remove all functions and facets accept \'diamondCut\' and \'facets\'', async () => {
    //   let selectors = []
    //   let facets = await diamondLoupeFacet.facets()
    //   for (let i = 0; i < facets.length; i++) {
    //     selectors.push(...facets[i].functionSelectors)
    //   }
    //   selectors = removeSelectors(selectors, ['facets()', 'diamondCut(tuple(address,uint8,bytes4[])[],address,bytes)'])
    //   tx = await diamondCutFacet.diamondCut(
    //     [{
    //       facetAddress: ethers.constants.AddressZero,
    //       action: FacetCutAction.Remove,
    //       functionSelectors: selectors
    //     }],
    //     ethers.constants.AddressZero, '0x', { gasLimit: 800000 })
    //   receipt = await tx.wait()
    //   if (!receipt.status) {
    //     throw Error(`Diamond upgrade failed: ${tx.hash}`)
    //   }
    //   facets = await diamondLoupeFacet.facets()
    //   assert.equal(facets.length, 2)
    //   assert.equal(facets[0][0], addresses[0])
    //   assert.sameMembers(facets[0][1], ['0x1f931c1c'])
    //   assert.equal(facets[1][0], addresses[1])
    //   assert.sameMembers(facets[1][1], ['0x7a0ed627'])
    // })
  
    // it('add most functions and facets', async () => {
    //   const diamondLoupeFacetSelectors = getSelectors(diamondLoupeFacet).remove(['supportsInterface(bytes4)'])
    //   const Test1Facet = await ethers.getContractFactory('Test1Facet')
    //   const Test2Facet = await ethers.getContractFactory('Test2Facet')
    //   // Any number of functions from any number of facets can be added/replaced/removed in a
    //   // single transaction
    //   const cut = [
    //     {
    //       facetAddress: addresses[1],
    //       action: FacetCutAction.Add,
    //       functionSelectors: diamondLoupeFacetSelectors.remove(['facets()'])
    //     },
    //     {
    //       facetAddress: addresses[2],
    //       action: FacetCutAction.Add,
    //       functionSelectors: getSelectors(ownershipFacet)
    //     },
    //     {
    //       facetAddress: addresses[3],
    //       action: FacetCutAction.Add,
    //       functionSelectors: getSelectors(Test1Facet)
    //     },
    //     {
    //       facetAddress: addresses[4],
    //       action: FacetCutAction.Add,
    //       functionSelectors: getSelectors(Test2Facet)
    //     }
    //   ]
    //   tx = await diamondCutFacet.diamondCut(cut, ethers.constants.AddressZero, '0x', { gasLimit: 8000000 })
    //   receipt = await tx.wait()
    //   if (!receipt.status) {
    //     throw Error(`Diamond upgrade failed: ${tx.hash}`)
    //   }
    //   const facets = await diamondLoupeFacet.facets()
    //   const facetAddresses = await diamondLoupeFacet.facetAddresses()
    //   assert.equal(facetAddresses.length, 5)
    //   assert.equal(facets.length, 5)
    //   assert.sameMembers(facetAddresses, addresses)
    //   assert.equal(facets[0][0], facetAddresses[0], 'first facet')
    //   assert.equal(facets[1][0], facetAddresses[1], 'second facet')
    //   assert.equal(facets[2][0], facetAddresses[2], 'third facet')
    //   assert.equal(facets[3][0], facetAddresses[3], 'fourth facet')
    //   assert.equal(facets[4][0], facetAddresses[4], 'fifth facet')
    //   assert.sameMembers(facets[findAddressPositionInFacets(addresses[0], facets)][1], getSelectors(diamondCutFacet))
    //   assert.sameMembers(facets[findAddressPositionInFacets(addresses[1], facets)][1], diamondLoupeFacetSelectors)
    //   assert.sameMembers(facets[findAddressPositionInFacets(addresses[2], facets)][1], getSelectors(ownershipFacet))
    //   assert.sameMembers(facets[findAddressPositionInFacets(addresses[3], facets)][1], getSelectors(Test1Facet))
    //   assert.sameMembers(facets[findAddressPositionInFacets(addresses[4], facets)][1], getSelectors(Test2Facet))
    // })
  })
  
require("dotenv").config()

const ProxyContract = artifacts.require("AdminUpgradeabilityProxy");
const Web3 = require('web3');

const abiNFT = require('../build/contracts/ERC1155ERC721.json')
const MintTokenUtil = require('../web3test/mintToken')

// Ganashe
const web3GanasheProvider = process.env.PROVIDER;
const chainId = process.env.CHAIN_ID
const mintFee = process.env.MINT_FEE

contract('AdminUpgradeabilityProxy', function([deployer, user1, user2, user3]){
    let proxyDeployed;
    let web3;
    let proxyContract;
    let BN;
    let token721Id;
    let token1155Id;

    before('before', async () => {
      proxyDeployed = await ProxyContract.deployed();
      web3 = new Web3(new Web3.providers.HttpProvider(web3GanasheProvider));
      proxyContract = new web3.eth.Contract(abiNFT.abi, proxyDeployed.address);
      BN = web3.utils.BN;

      //Mint test Token
      token721Id = await MintTokenUtil.mintTestToken(web3, chainId, proxyContract, mintFee, 0, 1, user1, user1)
      token1155Id = await MintTokenUtil.mintTestToken(web3, chainId, proxyContract, mintFee, 1, 5, user1, user1)
    })
    
    it('transferFrom NFT(721)', async () =>{
      await proxyContract.methods.transferFrom(user1, user2, token721Id)
        .send({ 
            from: user1,
            gas: '6721975', 
            chainId: chainId
        })

      let balanceUser1 = await proxyContract.methods.balanceOf(user1, token721Id).call()
      let balanceUser2 = await proxyContract.methods.balanceOf(user2, token721Id).call()
      assert.equal(balanceUser1, 0, 'transferFrom User1')
      assert.equal(balanceUser2, 1, 'transferFrom User2')

      await proxyContract.methods.safeTransferFrom(user2, user1, token721Id)
        .send({ 
            from: user2,
            gas: '6721975', 
            chainId: chainId
        })
      
      balanceUser1 = await proxyContract.methods.balanceOf(user1, token721Id).call()
      balanceUser2 = await proxyContract.methods.balanceOf(user2, token721Id).call()
      assert.equal(balanceUser1, 1)
      assert.equal(balanceUser2, 0)
    })

    it('safeTransferFrom NFT(1155)', async () =>{
      await proxyContract.methods.safeTransferFrom(user1, user2, token1155Id, 1, '0x')
        .send({ 
            from: user1,
            gas: '6721975', 
            chainId: chainId
        })

      const balanceUser = await proxyContract.methods.balanceOfBatch([user1, user2], [token1155Id, token1155Id]).call()
      assert.equal(balanceUser[0], 4, 'transferFrom User1')
      assert.equal(balanceUser[1], 1, 'transferFrom User2')
    })

    it('Extract Token', async () =>{
      const result = await proxyContract.methods.extractERC721(token1155Id, user2)
        .send({ 
            from: user1,
            gas: '6721975', 
            chainId: chainId
        })
      
      const extractTknId = result.events.Transfer.returnValues._tokenId
      const balanceUser = await proxyContract.methods.balanceOfBatch([user1, user2, user2], [token1155Id, token1155Id, extractTknId]).call()
      assert.equal(balanceUser[0], 3)
      assert.equal(balanceUser[1], 1, 'user2 1155')
      assert.equal(balanceUser[2], 1, 'user2 extracted NFT')
      const worthOfToken1155 = await proxyContract.methods.worthOf(token1155Id).call()
      const worthOfExtractTkn = await proxyContract.methods.worthOf(extractTknId).call()
      assert.equal(worthOfToken1155, worthOfExtractTkn)
    })

    //before 0: 1(721)/3, 1: 1(extract)/1 
    //after  0: 1/3, 1: 1(extract) , 2: 0/1 
    it('Approve', async () =>{

      await proxyContract.methods.approve(user3, token721Id)
        .send({ 
            from: user1,
            gas: '6721975', 
            chainId: chainId
        })
      
      // owner is not changed
      let balanceUser1 = await proxyContract.methods.balanceOf(user1, token721Id).call()
      let balanceUser2 = await proxyContract.methods.balanceOf(user3, token721Id).call()
      assert.equal(balanceUser1, 1)
      assert.equal(balanceUser2, 0)
      
      //
      let approvedAddr = await proxyContract.methods.getApproved(token721Id).call()
      assert.equal(user3, approvedAddr)

      //permitted
      await proxyContract.methods.transferFrom(user1, user2, token721Id)
        .send({ 
            from: user3,
            gas: '6721975', 
            chainId: chainId
        })
      
      balanceUser1 = await proxyContract.methods.balanceOf(user1, token721Id).call()
      balanceUser2 = await proxyContract.methods.balanceOf(user2, token721Id).call()
      assert.equal(balanceUser1, 0, 'transferFrom User1')
      assert.equal(balanceUser2, 1, 'transferFrom User2')
      
      //clear approved operator
      approvedAddr = await proxyContract.methods.getApproved(token721Id).call()
      assert.equal(0, approvedAddr)
      
      // user2 => user3
      await proxyContract.methods.setApprovalForAll(user3, true)
        .send({ 
            from: user2,
            gas: '6721975', 
            chainId: chainId
        })
      
      await proxyContract.methods.transferFrom(user2, user1, token721Id)
        .send({ 
            from: user3,
            gas: '6721975', 
            chainId: chainId
        })
      
      balanceUser1 = await proxyContract.methods.balanceOf(user1, token721Id).call()
      balanceUser2 = await proxyContract.methods.balanceOf(user2, token721Id).call()
      assert.equal(balanceUser1, 1, 'transferFrom User1')
      assert.equal(balanceUser2, 0, 'transferFrom User2')
    
      let approved = await proxyContract.methods.isApprovedForAll(user2, user3).call()
      assert.equal(approved, true)

      await proxyContract.methods.setApprovalForAll(user3, false)
      .send({ 
          from: user2,
          gas: '6721975', 
          chainId: chainId
      });

      approved = await proxyContract.methods.isApprovedForAll(user2, user3).call()
      assert.equal(approved, false)

      balanceUser1 = await proxyContract.methods.balanceOf(user2, token1155Id).call()
      assert.equal(balanceUser1, 1)
      let errorOccured = false
      try{
        await proxyContract.methods.safeTransferFrom(user2, user3, token1155Id, 1, '0x')
          .send({ 
              from: user3,
              gas: '6721975', 
              chainId: chainId
          })
      }catch (e){
        errorOccured = true
      }

      assert.equal(errorOccured, true)

      await proxyContract.methods.setApprovalForAll(user3, true)
        .send({ 
            from: user2,
            gas: '6721975', 
            chainId: chainId
        });

      await proxyContract.methods.safeTransferFrom(user2, user3, token1155Id, 1, '0x')
        .send({ 
            from: user3,
            gas: '6721975', 
            chainId: chainId
        })

      const balanceUser = await proxyContract.methods.balanceOfBatch([user2, user3], [token1155Id, token1155Id]).call()
      assert.equal(balanceUser[0], 0)
      assert.equal(balanceUser[1], 1, 'user3 1155')
    })

});

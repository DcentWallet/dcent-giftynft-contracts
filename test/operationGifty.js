require("dotenv").config()

const ProxyContract = artifacts.require("AdminUpgradeabilityProxy");
const Web3 = require('web3');

const abiNFT = require('../build/contracts/ERC1155ERC721.json')
const MintTokenUtil = require('../web3test/mintToken')

// Ganashe
const web3GanasheProvider = process.env.PROVIDER;
const chainId = process.env.CHAIN_ID
const mintFee = '1'

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

      await proxyContract.methods.setMintingFee(new BN(web3.utils.toWei(mintFee, 'ether').toString()))
        .send({ 
            from: deployer,
            gas: '6721975', 
            chainId: chainId
        })
      //Mint test Token
      token721Id = await MintTokenUtil.mintTestToken(web3, chainId, proxyContract, mintFee, 0, 1, user1, user1)
      token1155Id = await MintTokenUtil.mintTestToken(web3, chainId, proxyContract, mintFee, 1, 5, user1, user1)
    })
    
    // mint 6 => withdraw 3
    it('Open Envelope', async () =>{
      const worthOfToken1155 = await proxyContract.methods.worthOf(token1155Id).call()
      const worthOfToken721 = await proxyContract.methods.worthOf(token721Id).call()
      const balanceOfUser3 =  await web3.eth.getBalance(user3)
      const contractBalance =  await web3.eth.getBalance(proxyDeployed.address)
      await proxyContract.methods.openEnvelope(user3, token721Id, 1)
        .send({ 
            from: user1,
            gas: '6721975', 
            chainId: chainId
        })
      
      await proxyContract.methods.openEnvelope(user3, token1155Id, 2)
        .send({ 
            from: user1,
            gas: '6721975', 
            chainId: chainId
        })
      
      const balanceOfUser3After =  await web3.eth.getBalance(user3)
      const withdrawBalance = new BN(worthOfToken721)
                          .add(new BN(worthOfToken1155).mul(new BN(2)))
      assert.equal(new BN(balanceOfUser3After).cmp(new BN(balanceOfUser3).add(withdrawBalance)), 0)
      const contractBalanceAfter =  await web3.eth.getBalance(proxyDeployed.address)
      assert.equal(new BN(contractBalanceAfter).cmp(new BN(contractBalance).sub(withdrawBalance)), 0)
    })

    it('Withdraw Fee', async () =>{
      const balanceOfOwner =  await web3.eth.getBalance(deployer)
      const feeForMint = new BN(web3.utils.toWei(mintFee, 'ether'))
      const feeForMint2 = await proxyContract.methods.getMintFee().call()
      assert.equal(feeForMint.cmp(new BN(feeForMint2)), 0)
      await proxyContract.methods.withdrawFee()
        .send({ 
            from: deployer,
            gas: '6721975', 
            chainId: chainId
        })
      
      const accmulateFee = feeForMint.mul(new BN(6))
      await proxyContract.methods.withdrawFee()
        .send({ 
            from: deployer,
            gas: '6721975', 
            chainId: chainId
        })
      
      const balanceOfOwnerAfter = await web3.eth.getBalance(deployer)
      console.log(balanceOfOwnerAfter, balanceOfOwner)
      assert.equal(new BN(balanceOfOwnerAfter).cmp(new BN(balanceOfOwner)), 1)
      assert.equal(accmulateFee.cmp(new BN(balanceOfOwnerAfter).sub(new BN(balanceOfOwner))), 1)

      const contractBalance =  await web3.eth.getBalance(proxyDeployed.address)
      const worthOfToken1155 = await proxyContract.methods.worthOf(token1155Id).call() 
      // 3 NFT is Remained 
      assert.equal(new BN(contractBalance).sub(new BN(worthOfToken1155).mul(new BN(3))).cmp(new BN(0)), 0) 
    })
});

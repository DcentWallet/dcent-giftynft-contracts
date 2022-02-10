require("dotenv").config()

const ProxyContract = artifacts.require("AdminUpgradeabilityProxy");
const Web3 = require('web3');

const abiNFT = require('../build/contracts/ERC1155ERC721.json')
// Ganashe
const web3GanasheProvider = process.env.PROVIDER;
const chainId = process.env.CHAIN_ID
const nftWorth = '0.1'
const mintFee = process.env.MINT_FEE

contract('AdminUpgradeabilityProxy', function([deployer, user1, user2]){
    let mintDeployed;
    let web3;
    let mintContract;
    let BN;
    let token721Id;
    let token1155Id;
    before('before', async () => {
      // console.log('=>Enter before')
      mintDeployed = await ProxyContract.deployed();
      web3 = new Web3(new Web3.providers.HttpProvider(web3GanasheProvider));
      
      mintContract = new web3.eth.Contract(abiNFT.abi, mintDeployed.address);
      BN = web3.utils.BN;
    })
    
    it('first NFT(721) mint', async () =>{
      let balance = new BN(web3.utils.toWei(nftWorth, 'ether'))
      let feeForMint = new BN(web3.utils.toWei(mintFee, 'ether'))
      let supply = 1
      feeForMint = feeForMint.add(balance).mul(new BN(supply))
      
      let result = await mintContract.methods.mint(0, '0xdeadcafe', supply, user1, balance.toString(), '0x0').send({
        from: user1,
        value: feeForMint.toString(),
        gas: '6721975', 
        chainId: chainId
      })
      let tokenId = result.events.TransferSingle.returnValues._id
      token721Id = '0x' + new BN(tokenId).toString('hex')
      
      let balanceNft = await mintContract.methods.balanceOf(user1, token721Id).call()
      assert.equal(balanceNft, supply,  'count: ' + supply)
    })

    it('first NFT(1155) mint', async () =>{
      let balance = new BN(web3.utils.toWei(nftWorth, 'ether'))
      let feeForMint = new BN(web3.utils.toWei(mintFee, 'ether'))
      let supply = 3
      feeForMint = feeForMint.add(balance).mul(new BN(supply))
      
      let result = await mintContract.methods.mint(1, '0xdeadcafe', supply, user1, balance.toString(), '0x0').send({
        from: user1,
        value: feeForMint.toString(),
        gas: '6721975', 
        chainId: chainId
      })
      let tokenId = result.events.TransferSingle.returnValues._id
      token1155Id = '0x' + new BN(tokenId).toString('hex')
      let balanceNft = await mintContract.methods.balanceOf(user1, token1155Id).call()
      assert.equal(balanceNft, supply, 'count: ' + supply)
    })

    it('Err Wrong value', async () =>{
      let balance = new BN(web3.utils.toWei(nftWorth, 'ether'))
      let feeForMint = new BN(web3.utils.toWei('0.1', 'ether'))
      let supply = 1
      feeForMint = feeForMint.add(balance).mul(new BN(supply))
      let errorOccurred = false
      try {
        await mintContract.methods.mint(2, '0xdeadcafe', supply, user1, balance.toString(), '0x0').send({
          from: user1,
          value: feeForMint.toString(),
          gas: '6721975', 
          chainId: chainId
        })
      } catch (e) {
        errorOccurred = true
      }
      assert.equal(errorOccurred, true)
    })

});

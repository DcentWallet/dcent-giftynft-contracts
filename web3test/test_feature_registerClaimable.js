require("dotenv").config()
const Web3 = require('web3');
const abiNFT = require('../build/contracts/ERC1155ERC721.json')
const abiClaimable = require('../build/contracts/RegistClaimable.json')

//provider set
const web3GanasheProvider = process.env.PROVIDER
const web3 = new Web3(new Web3.providers.HttpProvider(web3GanasheProvider));
const BN = web3.utils.BN;

////////////////////////////////////////////////////////////////////
////////////////////   SET CONFIG      /////////////////////////////
////////////////////////////////////////////////////////////////////
const proxyAddress = process.env.PROXY
const registerClaimable = process.env.REGISTER
const mintFee = process.env.MINT_FEE
const chainId = process.env.CHAIN_ID


const NFTContract = new web3.eth.Contract(abiNFT.abi, proxyAddress)
const ClaimContract = new web3.eth.Contract(abiClaimable.abi, registerClaimable)


const worthOf = async (testTokenId) => {
  let result = await NFTContract.methods.worthOf(testTokenId).call()
  console.log('worthOf= ', web3.utils.fromWei(result, 'ether'), ' MATIC') 
  result = await NFTContract.methods.contractOfToken(testTokenId).call()
  console.log('contractOfToken= ', result) 
}

const testClaimable = async () => {
  const accounts = await web3.eth.getAccounts()
  let feeForMint = new BN(web3.utils.toWei(mintFee, 'ether'))
  const includeBalance = new BN(web3.utils.toWei('0.01', 'ether'))
  const totalSupply = '2'
  feeForMint = feeForMint.add(includeBalance).mul(new BN(totalSupply))
  
  //Mint 1155 to accounts[1]
  console.log('=============MINT 1155==============================')
  let result = await NFTContract.methods
    .mint(519, '0xaa0000aa', totalSupply, accounts[1], includeBalance.toString(), '0x0')
    .send({
      from: accounts[5],
      value: feeForMint.toString(),
      gas: '6721975', //118401 (used)
      chainId: chainId
    })
  
  let tokenId = result.events.TransferSingle.returnValues._id
  tokenId = '0x' + new BN(tokenId).toString('hex')
  console.log('tokenId: ', tokenId)
  await worthOf(tokenId)

  //approve contract
  await NFTContract.methods
    .setApprovalForAll(registerClaimable, true)
    .send({
      from: accounts[1],
      gas: '6721975', //118401 (used)
      chainId: chainId
    })
  
  console.log('approved successed')
  //registerclaimable - 2
  await ClaimContract.methods
    .registToken(tokenId, totalSupply, '1000000000000000000')
    .send({
      from: accounts[1],
      gas: '6721975', //118401 (used)
      chainId: chainId
    })
  
  console.log('registered--')
  //claim cnt 1
  result = await ClaimContract.methods
    .claimToken(tokenId, '0x0')
    .send({
      from: accounts[7],
      value: '1000000000000000000',
      gas: '6721975', //118401 (used)
      chainId: chainId
    })
  
  console.log('Claim', result)
  // transfer 1
  await NFTContract.methods
    .safeTransferFrom(accounts[1], accounts[2], tokenId, 1, '0x0')
    .send({
      from: accounts[1],
      gas: '6721975', //118401 (used)
      chainId: chainId
    })

  //claim -error
  try{
    result = await ClaimContract.methods
      .claimToken(tokenId, '0x0')
      .send({
        from: accounts[6],
        value: '1000000000000000000',
        gas: '6721975', //118401 (used)
        chainId: chainId
      })
    
    console.log('Claim(Excase)', result)
  }catch (e) {
    console.log(e.toString())
  }

  //balanceOf token
  bulkSendTo = [accounts[1], accounts[2], accounts[6], accounts[7]]
  let bulkTknId = [tokenId, tokenId, tokenId, tokenId]

  result = await NFTContract.methods.balanceOfBatch(bulkSendTo, bulkTknId).call()
  console.log('balance of', result)

  //getCollectedFee
  result = await ClaimContract.methods.getCollectedFee(accounts[1]).call()
  console.log('getCollectedFee', web3.utils.fromWei(result, 'ether'), ' ETH')
  
  // display amount
  let balance = await web3.eth.getBalance(accounts[8])
  console.log('balance= ',  web3.utils.fromWei(balance, 'ether'), ' ETH')
  await ClaimContract.methods.withdrawFee(accounts[8])
          .send({
            from: accounts[1],
            gas: '6721975', //118401 (used)
            chainId: chainId
          })
  
  // display amount
  balance = await web3.eth.getBalance(accounts[8])
  console.log('balance= ', web3.utils.fromWei(balance, 'ether'), ' ETH')

  result = await ClaimContract.methods.getRemainAmount(accounts[1], tokenId).call()
  console.log('getRemainAmount', result)

  result = await ClaimContract.methods.getCollectedFee(accounts[1]).call()
  console.log('getCollectedFee', result)
}

testClaimable()

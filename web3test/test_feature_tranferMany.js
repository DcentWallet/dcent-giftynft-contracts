require("dotenv").config()
const Web3 = require('web3');
const abiNFT = require('../build/contracts/ERC1155ERC721.json')

//provider set
const web3GanasheProvider = process.env.PROVIDER
const web3 = new Web3(new Web3.providers.HttpProvider(web3GanasheProvider));
const BN = web3.utils.BN;

////////////////////////////////////////////////////////////////////
////////////////////   SET CONFIG      /////////////////////////////
////////////////////////////////////////////////////////////////////
const proxyAddress = process.env.PROXY
const mintFee = process.env.MINT_FEE
const chainId = process.env.CHAIN_ID


const NFTContract = new web3.eth.Contract(abiNFT.abi, proxyAddress)

const worthOf = async (testTokenId) => {
  let result = await NFTContract.methods.worthOf(testTokenId).call()
  console.log('worthOf= ', web3.utils.fromWei(result, 'ether'), ' MATIC') 
  result = await NFTContract.methods.contractOfToken(testTokenId).call()
  console.log('contractOfToken= ', result) 
}

const testTransferMany = async () => {
  const accounts = await web3.eth.getAccounts()
  let feeForMint = new BN(web3.utils.toWei(mintFee, 'ether'))
  const includeBalance = new BN(web3.utils.toWei('0.01', 'ether'))
  const totalSupply = '20'
  feeForMint = feeForMint.add(includeBalance).mul(new BN(totalSupply))
  
  //Mint 1155 to accounts[1]
  console.log('=============MINT 1155==============================')
  let result = await NFTContract.methods
    .mint(201, '0xaa0000aa', totalSupply, accounts[1], includeBalance.toString(), '0x0')
    .send({
      from: accounts[3],
      value: feeForMint.toString(),
      gas: '6721975', //118401 (used)
      chainId: chainId
    })
  
  let tokenId = result.events.TransferSingle.returnValues._id
  tokenId = '0x' + new BN(tokenId).toString('hex')
  console.log('tokenId: ', tokenId)
  await worthOf(tokenId)
 
  let bulkSendTo = [accounts[2], accounts[3], accounts[4], accounts[5], accounts[6]]
  //Transfer Many
  try{
    result = await NFTContract.methods
      .transferMany(accounts[1], bulkSendTo, tokenId, 2, '0x0')
      .send({
        from: accounts[1],
        gas: '6721975', //118401 (used)
        chainId: chainId
      })
  } catch (e) {
    console.log('============   ERROR  ==============')
    console.log(e.toString())
    console.log(JSON.stringify(e))
  }

  //balance of
  bulkSendTo = [accounts[1], accounts[2], accounts[3], accounts[4], accounts[5], accounts[6], accounts[7]]
  let bulkTknId = [tokenId, tokenId, tokenId, tokenId, tokenId, tokenId, tokenId,]

  result = await NFTContract.methods.balanceOfBatch(bulkSendTo, bulkTknId).call()
  console.log('result', result)
}

testTransferMany()

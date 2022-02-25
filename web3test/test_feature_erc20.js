require("dotenv").config()
const Web3 = require('web3');
const abiNFT = require('../build/contracts/ERC1155ERC721.json')
const abiERC20 = require('../build/contracts/MyToken.json')

//provider set
const web3GanasheProvider = process.env.PROVIDER
const web3 = new Web3(new Web3.providers.HttpProvider(web3GanasheProvider));
const BN = web3.utils.BN;

////////////////////////////////////////////////////////////////////
////////////////////   SET CONFIG      /////////////////////////////
////////////////////////////////////////////////////////////////////
const proxyAddress = process.env.PROXY
const myTokenAddress = process.env.ERC20
const mintFee = process.env.MINT_FEE
const chainId = process.env.CHAIN_ID


const NFTContract = new web3.eth.Contract(abiNFT.abi, proxyAddress)
const ERC20Contract = new web3.eth.Contract(abiERC20.abi, myTokenAddress)

const getMyTokenBalance = async (address1, address2) => {
  let response = await ERC20Contract.methods.balanceOf(address1).call()
  console.log('address1(MyToken Balance) = ',web3.utils.fromWei(response, 'ether'), ' MTK')
  response = await ERC20Contract.methods.balanceOf(address2).call()
  console.log('address2(MyToken Balance) = ', web3.utils.fromWei(response, 'ether'), ' MTK')
  console.log('=======================================')
}

const worthOf = async (testTokenId) => {
  let result = await NFTContract.methods.worthOf(testTokenId).call()
  console.log('worthOf= ', web3.utils.fromWei(result, 'ether'), ' MTK') 
  result = await NFTContract.methods.contractOfToken(testTokenId).call()
  console.log('contractOfToken= ', result) 
}

const testErc20NFTProcess = async () => {
  const accounts = await web3.eth.getAccounts()
  let feeForMint = new BN(web3.utils.toWei(mintFee, 'ether'))
  const includeBalance = new BN(web3.utils.toWei('1', 'ether'))
  const totalSupply = '10'
  feeForMint = feeForMint.mul(new BN(totalSupply))
  //approve
  await ERC20Contract.methods
    .approve(proxyAddress, includeBalance.mul(new BN(totalSupply)).toString())
    .send({
      from: accounts[0],
      gas: '6721975', //118401 (used)
      chainId: chainId
    })

  //Mint 1155 to accounts[1]
  console.log('=============MINT 1155==============================')
  let result = await NFTContract.methods
    .mint(myTokenAddress, 200, '0xaa0000aa', totalSupply, accounts[1], includeBalance.toString(), '0x0')
    .send({
      from: accounts[0],
      value: feeForMint.toString(),
      gas: '6721975', //118401 (used)
      chainId: chainId
    })
  
  let tokenId = result.events.TransferSingle.returnValues._id
  tokenId = '0x' + new BN(tokenId).toString('hex')
  await worthOf(tokenId)
  

  //balance of Mytoken
  await getMyTokenBalance(proxyAddress, accounts[2])
  
  console.log('=============ENVELOPE 1155==============================')
  //openEnvelope(ERC1155) => to accounts[2]
  await NFTContract.methods.openEnvelope(accounts[2], tokenId, 3).send({
    from: accounts[1],
    gas: '6721975', //118401 (used)
    chainId: chainId
  })

  //balance of Mytoken
  await getMyTokenBalance(proxyAddress, accounts[2])

  console.log('=============EXTRACT 1155==============================')
  //Extract to accounts[1]
  result = await NFTContract.methods.extractERC721(tokenId, accounts[1])
        .send({ 
            from: accounts[1],
            gas: '6721975', 
            chainId: chainId
        })

  const extractTknId = result.events.Transfer.returnValues._tokenId
  console.log('extractTknId', extractTknId)
  result = await NFTContract.methods.balanceOf(accounts[1], tokenId).call()
  console.log('balanceOf(1155) : ', result)
  await worthOf(extractTknId)
  result = await NFTContract.methods.balanceOf(accounts[1], extractTknId).call()
  console.log('balanceOf(721) : ', result)

  console.log('=============ENVELOPE 721==============================')
  //openEnvelope(ERC721)
  await NFTContract.methods.openEnvelope(accounts[2], extractTknId, 1).send({
    from: accounts[1],
    gas: '6721975', //118401 (used)
    chainId: chainId
  })
  result = await NFTContract.methods.balanceOf(accounts[1], extractTknId).call()
  console.log('balanceOf(721) after Envelope : ', result) // still 1
  await worthOf(extractTknId)
  await worthOf(tokenId)
  //balance of Mytoken
  await getMyTokenBalance(proxyAddress, accounts[2])
}

testErc20NFTProcess()

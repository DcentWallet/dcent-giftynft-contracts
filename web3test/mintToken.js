//
let mintUtil = {};

mintUtil.mintTestToken = async (web3, chainId, contract, mintFee, tokenIndex, supply, from , to, worth = '0.1') => {
  const BN = web3.utils.BN;
  const balance = new BN(web3.utils.toWei(worth, 'ether'))
  let feeForMint = new BN(web3.utils.toWei(mintFee, 'ether'))
  feeForMint = feeForMint.add(balance).mul(new BN(supply))
  
  const result = await contract.methods.mint(tokenIndex, '0xdeadcafe', supply, to, balance.toString(), '0x0').send({
    from: from,
    value: feeForMint.toString(),
    gas: '6721975', 
    chainId: chainId
  })
  const tokenId = result.events.TransferSingle.returnValues._id
  return '0x' + new BN(tokenId).toString('hex')
}

module.exports = mintUtil

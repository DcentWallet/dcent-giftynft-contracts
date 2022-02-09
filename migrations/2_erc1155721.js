const ERC1155ERC721 = artifacts.require("ERC1155ERC721");
const ProxyContract = artifacts.require("AdminUpgradeabilityProxy");

module.exports = function async (deployer, network, accounts) {
  deployer.deploy(ERC1155ERC721).then((instance) => {
    const contract = new web3.eth.Contract(instance.abi, instance.address)
    return deployer.deploy(ProxyContract, instance.address, accounts[0], contract.methods.initialize('100000000000000', accounts[0]).encodeABI())
  })
};

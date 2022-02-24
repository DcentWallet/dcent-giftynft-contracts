const ERC1155ERC721 = artifacts.require("ERC1155ERC721");
const ProxyContract = artifacts.require("AdminUpgradeabilityProxy");
const ObjectLib32 = artifacts.require("ObjectLib32");
const AddressUtils = artifacts.require("AddressUtils");

module.exports = async function (deployer, network, accounts) {
  deployer.deploy(AddressUtils).then(() => {
    return deployer.deploy(ObjectLib32)
  })
  .then(async () => {
    deployer.link(ObjectLib32, [ERC1155ERC721])
    deployer.link(AddressUtils, [ERC1155ERC721])
    return deployer.deploy(ERC1155ERC721)
  })
  .then((instance) => {
    const contract = new web3.eth.Contract(instance.abi, instance.address)
    return deployer.deploy(ProxyContract, instance.address, accounts[0], contract.methods.initialize('100000000000000', accounts[0]).encodeABI())
  })
};

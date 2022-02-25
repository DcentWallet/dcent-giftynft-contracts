// SPDX-License-Identifier: MIT
/*
 *
*/
pragma solidity ^0.8.0;

import "./ERC1155ERC721.sol";
import "./Base/Ownable.sol";

contract RegistClaimable is Ownable {
  
  uint256 private constant IS_NFT = 0x0000000000000000000000000000000000000000800000000000000000000000;

  //Storage
  ERC1155ERC721 private giftyNftContract;
  mapping(uint256 => uint256) private claimableTokenAmount; // [tokenId][totalAmount]
  mapping(uint256 => uint256) private claimableTokenMinFee; // [tokenId][minRequireFee]
  mapping(uint256 => address) private claimableTokenOwner; // [tokenId][tokenOwner]
  mapping(address => uint256) private collectedFee;         // [address][tokenId]

  //Event
  event OpenClaim(uint256 indexed _tokenId, uint256 _amount, uint256 _minFee);
  event ExpireClaim(uint256 indexed _tokenId);
  event Upgraded(address indexed _contract);

  // construct 
  constructor(
    address _giftyNftContractAddr,
    address _ownerAdmin
  ) Ownable(_ownerAdmin) {
     _upgradeTokenImpl(_giftyNftContractAddr);
  }

  function getRemainAmount(
    address _owner,
    uint256 _id
  ) public view returns (uint256) {
    require(_owner != address(0));

    uint256 currentBalance = _balanceOf(_owner, _id);
    if(currentBalance > claimableTokenAmount[_id]){
      return claimableTokenAmount[_id];
    }
    
    return currentBalance;
  }
  
  function _balanceOf(
    address _owner, 
    uint256 _id
  ) internal view returns (uint256)
  {
    return giftyNftContract.balanceOf(_owner, _id);
  }

  function getClaimMinFee(
    uint256 _id
  ) public view returns (uint256){
    return claimableTokenMinFee[_id];
  }

  function getCollectedFee (
    address _owner
  ) external view returns (uint256){
    return collectedFee[_owner];
  }

  function withdrawFee(
    address _to
  ) external {
    require(_to != address(0));

    uint256[] memory collected = new uint256[](1);
    collected[0] = collectedFee[msg.sender];
    collectedFee[msg.sender] = 0;
    payable(_to).transfer(collected[0]);
  }

  function registToken(
    uint256 _id,
    uint256 _total,
    uint256 _minFee
  ) external {
    require(_id & IS_NFT == 0);
    require(_balanceOf(msg.sender, _id) >= _total, "NE.T");
    claimableTokenAmount[_id] = _total;
    claimableTokenMinFee[_id] = _minFee;
    claimableTokenOwner[_id] = msg.sender;
    emit OpenClaim(_id, _total, _minFee);
  }

  function claimToken(
    uint256 _id,
    bytes calldata _data
  ) external payable returns (bool) {
    require(msg.value >= claimableTokenMinFee[_id], "LF");
    require(claimableTokenAmount[_id] > 0, "Expired");
    // require(getRemainAmount(claimableTokenOwner[_id], _id) > 0, "ERR_EXPIRED_TOKEN");
    require(_balanceOf(msg.sender, _id) == 0, "Duplicate");

    uint256 remain = getRemainAmount(claimableTokenOwner[_id], _id);
    // Owner trasfer Registered Token, how to manage this exception?
    if(remain == 0 && claimableTokenOwner[_id] != address(0)){
      claimableTokenAmount[_id] = 0;
      // revert("ERR_EXPIRED_TOKEN");
      emit ExpireClaim(_id);
      return false;
    }
    
    collectedFee[claimableTokenOwner[_id]] += msg.value;
    claimableTokenAmount[_id]--;
    giftyNftContract.safeTransferFrom(claimableTokenOwner[_id], msg.sender, _id, 1, _data);
    if(claimableTokenAmount[_id] == 0){
      emit ExpireClaim(_id);
    }

    return true;
  }

  // Owner Only function
  function changeGiftyContract(
    address _giftyNftContractAddr
  ) external onlyOwner {
    _upgradeTokenImpl(_giftyNftContractAddr);
  } 

  function _upgradeTokenImpl(address _giftyNftContractAddr) internal {
    require(_giftyNftContractAddr != address(0));
    giftyNftContract = ERC1155ERC721(_giftyNftContractAddr);
    emit Upgraded(_giftyNftContractAddr);
  }
  //////////////////////////////////////////////////////////////
  // NFT Receive Interface??
  // 
}

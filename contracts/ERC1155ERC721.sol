// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './Base/OwnableForProxyImpl.sol';

import './Interface/ERC1155.sol';
import "./Interface/ERC1155TokenReceiver.sol";

import './Interface/ERC721.sol';
import './Interface/ERC721TokenReceiver.sol';

import './Libraries/AddressUtils.sol';
import './Libraries/ObjectLib32.sol';
import './Libraries/SafeMath.sol';

contract ERC1155ERC721 is OwnableProxyImpl, ERC1155, ERC721{
    // Libraries
    using AddressUtils for address;
    using SafeMath for uint256;
    using ObjectLib32 for uint256;
    using ObjectLib32 for ObjectLib32.Operations;
    
    // Constants
    bytes4 private constant ERC1155_IS_RECEIVER = 0x4e2312e0;
    bytes4 private constant ERC1155_RECEIVED = 0xf23a6e61;
    bytes4 private constant ERC1155_BATCH_RECEIVED = 0xbc197c81;
    bytes4 private constant ERC721_RECEIVED = 0x150b7a02;
    bytes4 private constant ERC165ID = 0x01ffc9a7;
    uint256 private constant IS_NFT = 0x0000000000000000000000000000000000000000800000000000000000000000;
    uint256 private constant NOT_IS_NFT = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7FFFFFFFFFFFFFFFFFFFFFFF;
    // uint256 private constant NFT_INDEX = 0x00000000000000000000000000000000000000007FFFFFFF8000000000000000;
    uint256 private constant NOT_NFT_INDEX = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF800000007FFFFFFFFFFFFFFF;
    uint256 private constant URI_ID = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000007FFFFFFFFFFF8000;
    uint256 private constant PACK_INDEX = 0x0000000000000000000000000000000000000000000000000000000000007FFF;
    uint256  private constant CREATOR_ADDR = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000000;
    
    // Events
    event OpenEnvelope(
        uint256 indexed _tokenId,
        address _from,
        address _to
    );

    // Storage
    uint256 feeForMint;
    mapping(uint256 => bytes32) private metadataHash; // erc721 and erc1155
    mapping(address => uint256) private numNFTPerAddress; // erc721
    mapping(uint256 => address) private owners; // erc721
    mapping(uint256 => address) private erc721_operators; // erc721

    mapping(address => mapping(uint256 => uint256)) private packedTokenBalance; // erc1155
    mapping(address => mapping(address => bool)) private operatorsForAll; // erc721 and erc1155

    mapping(uint256 => uint32) private nextCollectionIndex; // extraction

    mapping(uint256 => uint256) private tokenIncludeBanace;
    mapping(address => uint48) private mintCounter;
    uint256 accmulateFee;
    
    // Implementation

    // constructor() {
    //     feeForMint = 0.0001 ether;
    // }

    function initialize(uint256 _mintFee, address _owner) public initializer {
        OwnableProxyImpl.initialize(_owner);
        feeForMint = _mintFee;
    }

    function setMintingFee(uint _fee) external onlyOwner {
        feeForMint = _fee;
    }

    function getMintFee()
        external
        view
        returns (uint256)
    {   
        return feeForMint;
    }

    //TEMPorary FUNCTION
    function setUri(bytes32 _hash, uint256 _tokenId) external onlyOwner{
        uint256 uriId = _tokenId & URI_ID;
        metadataHash[uriId] = _hash;
        emit URI(tokenURI(_tokenId), _tokenId);
    }

    function withdrawFee() external onlyOwner {
        uint256[] memory balance = new uint256[](1);
        balance[0] = accmulateFee;
        accmulateFee = 0;
        payable(msg.sender).transfer(balance[0]);
    }

    function worthOf(uint256 _id)
        public
        view
        returns (uint256)
    {   
        uint256 includeBalId = _id & NOT_NFT_INDEX;
        return tokenIncludeBanace[includeBalId];
    }

    function mintCount(address _owner)
        public
        view
        returns (uint48)
    {
       return mintCounter[_owner];
    }

    // only owner can envelope NFT/FT
    function openEnvelope(
        address _to,
        uint256 _tokenId,
        uint256 _nNum
    ) external {
        require(_to != address(0));
        require(!_to.isContract());
        uint256 includeBalId = _tokenId & NOT_NFT_INDEX;
        
        if (_tokenId & IS_NFT > 0) {
            require(owners[_tokenId] == msg.sender);
            require(erc721_operators[_tokenId] == address(0));
            // Not available _nNum
            // require(_nNum == 1, "Fail _nNum");
            uint256[] memory tokenWorth = new uint256[](1);
            tokenWorth[0] = tokenIncludeBanace[includeBalId];
            tokenIncludeBanace[includeBalId] = 0;
            payable(_to).transfer(tokenWorth[0]);
            emit URI(tokenURI(_tokenId), _tokenId);
        } else {
            require(_nNum > 0);
            (uint256 bin, uint256 index) = _tokenId.getTokenBinIndex();
            //burn token
            packedTokenBalance[msg.sender][bin] = packedTokenBalance[msg.sender][bin]
                .updateTokenBalance(index, _nNum, ObjectLib32.Operations.SUB);
            
            payable(_to).transfer(tokenIncludeBanace[includeBalId] * _nNum);
            emit TransferSingle(msg.sender, msg.sender, address(0), _tokenId, _nNum);
        }
        
        emit OpenEnvelope(_tokenId, msg.sender, _to);
    }

    // Mint ///////////////////////////////////////////////////////////////////////////
    function mint(
        // address _creator,//
        uint48 _packId,
        bytes32 _hash,
        uint256 _supply,
        address _owner,
        uint256 _includeBalance,
        bytes calldata _data
    ) external payable returns (uint256 tokenId) {
        require(_owner != address(0));
        // require(_creator == msg.sender);//
        require(_supply > 0 && _supply < 2**32);
        uint256 mintFee = feeForMint * _supply;
        require(msg.value >= mintFee);
        require ((msg.value - mintFee) == (_supply * _includeBalance));
        accmulateFee = accmulateFee.add(mintFee);
        tokenId = generateTokenId(msg.sender, _supply, _packId, 0);
        _mint(
            _hash,
            _supply,
            msg.sender,
            _owner,
            tokenId,
            _includeBalance,
            _data,
            false
        );
    }

    function generateTokenId(
        address _creator,
        uint256 _supply,
        uint48 _packId,
        uint16 _packIndex
    ) internal pure returns (uint256) {
        return
            uint256(uint160(_creator)) *
            uint256(2)**(256 - 160) + // CREATOR
            (_supply == 1 ? uint256(1) * uint256(2)**(256 - 160 - 1) : 0) + // minted as NFT (1) or FT (0) // IS_NFT
            uint256(_packId) *
            (uint256(2)**(256 - 160 - 1 - 32 - 48)) + // packId (unique pack) // PACk_ID
            _packIndex; // packIndex (position in the pack) // PACK_INDEX
    }

    function _mint(
        bytes32 _hash,
        uint256 _supply,
        address _operator,
        address _owner,
        uint256 _tokenId,
        uint256 _includeBalance,
        bytes memory _data,
        bool _extraction
    ) internal {
        uint256 uriId = _tokenId & URI_ID;
        uint256 includeBalId = _tokenId & NOT_NFT_INDEX;
        if (!_extraction) {
            require(uint256(metadataHash[uriId]) == 0, "exist");    
            metadataHash[uriId] = _hash;
        }
        tokenIncludeBanace[includeBalId] = _includeBalance;

        if (_supply == 1) {
            // ERC721
            numNFTPerAddress[_owner]++;
            owners[_tokenId] = _owner;
            emit Transfer(address(0), _owner, _tokenId);
        } else {
            (uint256 bin, uint256 index) = _tokenId.getTokenBinIndex();
            packedTokenBalance[_owner][bin] = packedTokenBalance[_owner][bin]
                .updateTokenBalance(
                index,
                _supply,
                ObjectLib32.Operations.REPLACE
            );
        }

        mintCounter[_operator]++;

        emit TransferSingle(_operator, address(0), _owner, _tokenId, _supply);
        require(
            _checkERC1155AndCallSafeTransfer(
                _operator,
                address(0),
                _owner,
                _tokenId,
                _supply,
                _data,
                false,
                false
            ),
            "rejected"
        );
    }

    // Transfer ///////////////////////////////////////////////////////////////////////////
        
    function _transferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value
    ) internal {
        require(_to != address(0));
        require(_from != address(0));
        if (_from != msg.sender) {
            require(
                operatorsForAll[_from][msg.sender] ||
                erc721_operators[_id] == msg.sender
            );
        }

        if (_id & IS_NFT > 0) {
            require(owners[_id] == _from);
            require(_value == 1);
            numNFTPerAddress[_from]--;
            numNFTPerAddress[_to]++;
            owners[_id] = _to;
            if (erc721_operators[_id] != address(0)) {
                erc721_operators[_id] = address(0);
            }
            emit Transfer(_from, _to, _id);
        } else {
            // if different owners it will fails
            require(_value > 0);
            (uint256 bin, uint256 index) = _id.getTokenBinIndex();
            packedTokenBalance[_from][bin] = packedTokenBalance[_from][bin]
                .updateTokenBalance(index, _value, ObjectLib32.Operations.SUB);
            packedTokenBalance[_to][bin] = packedTokenBalance[_to][bin]
                .updateTokenBalance(index, _value, ObjectLib32.Operations.ADD);
        }

        emit TransferSingle(
            msg.sender,
            _from,
            _to,
            _id,
            _value
        );
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external {
        _transferFrom(_from, _to, _id, _value);
        require( // solium-disable-line error-reason
            _checkERC1155AndCallSafeTransfer(
                msg.sender,
                _from,
                _to,
                _id,
                _value,
                _data,
                false,
                false
            ),
            "rejected"
        );
    }

    // NOTE: call data should be optimized to order _ids so packedBalance can be used efficiently
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external {
        _batchTransferFrom(_from, _to, _ids, _values);
        require( // solium-disable-line error-reason
            _checkERC1155AndCallSafeBatchTransfer(
                msg.sender,
                _from,
                _to,
                _ids,
                _values,
                _data
            )
        );
    }

    function _batchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _values
    ) internal {
        uint256 numItems = _ids.length;
        require(numItems > 0);
        require(numItems == _values.length);
        require(_to != address(0));
        require(_from != address(0));
        bool authorized = _from == msg.sender ||
                            operatorsForAll[_from][msg.sender];
                            
        uint256 bin;
        uint256 index;
        uint256 balFrom;
        uint256 balTo;

        // Last bin updated
        uint256 lastBin;
        uint256 numNFTs = 0;
        for (uint256 i = 0; i < numItems; i++) {
            if (_ids[i] & IS_NFT > 0) {
                require(
                    authorized || erc721_operators[_ids[i]] == msg.sender);
                require(owners[_ids[i]] == _from);
                require(_values[i] == 1);
                numNFTs++;
                numNFTPerAddress[_to]++;
                owners[_ids[i]] = _to;
                if (erc721_operators[_ids[i]] != address(0)) {
                    erc721_operators[_ids[i]] = address(0);
                }
                emit Transfer(_from, _to, _ids[i]);
            } else {
                require(authorized);
                require(_values[i] > 0);
                (bin, index) = _ids[i].getTokenBinIndex();
                // If first bin
                if (lastBin == 0) {
                    lastBin = bin;
                    balFrom = ObjectLib32.updateTokenBalance(
                        packedTokenBalance[_from][bin],
                        index,
                        _values[i],
                        ObjectLib32.Operations.SUB
                    );
                    balTo = ObjectLib32.updateTokenBalance(
                        packedTokenBalance[_to][bin],
                        index,
                        _values[i],
                        ObjectLib32.Operations.ADD
                    );
                } else {
                    // If new bin
                    if (bin != lastBin) {
                        // _ids need to be ordered appropriately to benefit for optimization
                        // Update storage balance of previous bin
                        packedTokenBalance[_from][lastBin] = balFrom;
                        packedTokenBalance[_to][lastBin] = balTo;

                        // Load current bin balance in memory
                        balFrom = packedTokenBalance[_from][bin];
                        balTo = packedTokenBalance[_to][bin];

                        // Bin will be the most recent bin
                        lastBin = bin;
                    }

                    // Update memory balance
                    balFrom = balFrom.updateTokenBalance(
                        index,
                        _values[i],
                        ObjectLib32.Operations.SUB
                    );
                    balTo = balTo.updateTokenBalance(
                        index,
                        _values[i],
                        ObjectLib32.Operations.ADD
                    );
                }
            }
        }

        if (numNFTs > 0) {
            numNFTPerAddress[_from] -= numNFTs;
        }

        if (bin != 0) { // if needed
            // Update storage of the last bin visited
            packedTokenBalance[_from][bin] = balFrom;
            packedTokenBalance[_to][bin] = balTo;
        }

        emit TransferBatch(
            msg.sender,
            _from,
            _to,
            _ids,
            _values
        );
    }
    
    //
    function balanceOf(address _owner, uint256 _id)
        public
        view
        returns (uint256)
    {
        if (_id & IS_NFT > 0) {
            if (owners[_id] == _owner) {
                return 1;
            } else {
                return 0;
            }
        }
        (uint256 bin, uint256 index) = _id.getTokenBinIndex();
        return packedTokenBalance[_owner][bin].getValueInBin(index);
    }

    function balanceOfBatch(
        address[] calldata _owners,
        uint256[] calldata _tokenIds
    ) external view returns (uint256[] memory) {
        require(_owners.length == _tokenIds.length);
        uint256[] memory balances = new uint256[](_tokenIds.length);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            balances[i] = balanceOf(_owners[i], _tokenIds[i]);
        }
        return balances;
    }

    // operators ///////////////////////////////////////////////////////////////////////////
    function setApprovalForAll(address _operator, bool _approved) external override(ERC1155, ERC721){
        _setApprovalForAll(msg.sender, _operator, _approved);
    }
    function _setApprovalForAll(
        address _sender,
        address _operator,
        bool _approved
    ) internal {
        require(_sender != address(0));
        require(_sender != _operator);
        require(_operator != address(0));

        operatorsForAll[_sender][_operator] = _approved;
        emit ApprovalForAll(_sender, _operator, _approved);
    }
    function isApprovedForAll(address _owner, address _operator)
        external
        view
        override(ERC1155, ERC721)
        returns (bool isOperator)
    {
        require(_owner != address(0));
        require(_operator != address(0));
        return operatorsForAll[_owner][_operator];
    }
    
    // ERC721 ///////////////////////////////////////
    function balanceOf(address _owner) external view returns (uint256 _balance)
    {
        require(_owner != address(0)); 
        return numNFTPerAddress[_owner];
    }
    
    function ownerOf(uint256 _id) external view returns (address _owner) {
        _owner = owners[_id];
        require(_owner != address(0)); 
    }

    function approve(address _operator, uint256 _id) external {
        address owner = owners[_id];
        require(owner != address(0));
        require( // solium-disable-line error-reason
            owner == msg.sender ||
                operatorsForAll[owner][msg.sender]
        );
        erc721_operators[_id] = _operator;
        emit Approval(owner, _operator, _id);
    }
    function getApproved(uint256 _id)
        external
        view
        returns (address _operator)
    {
        require(owners[_id] != address(0), "not exist"); 
        return erc721_operators[_id];
    }
    function transferFrom(address _from, address _to, uint256 _id) external {
        require(owners[_id] == _from, "_from"); 
        _transferFrom(_from, _to, _id, 1);
        require( // solium-disable-line error-reason
            _checkERC1155AndCallSafeTransfer(
                msg.sender,
                _from,
                _to,
                _id,
                1,
                "",
                true,
                false
            )
        );
    }
    function safeTransferFrom(address _from, address _to, uint256 _id)
        external
    {
        safeTransferFrom(_from, _to, _id, "");
    }
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        bytes memory _data
    ) public {
        require(owners[_id] == _from, "_from"); // solium-disable-line error-reason
        _transferFrom(_from, _to, _id, 1);
        require( // solium-disable-line error-reason
            _checkERC1155AndCallSafeTransfer(
                msg.sender,
                _from,
                _to,
                _id,
                1,
                _data,
                true,
                true
            )
        );
    }
    function name() external pure returns (string memory _name) {
        return "giftyNFT";
    }
    function symbol() external pure returns (string memory _symbol) {
        return "GFTY";
    }

    function toFullURI(bytes32 _hash, uint256 _tokenId)
        internal
        view
        returns (string memory)
    {
        uint256 includeBalId = _tokenId & NOT_NFT_INDEX;
        return
            string(
                abi.encodePacked(
                    "ipfs://bafybei",
                    hash2base32(_hash),
                    "/t/",
                    // uint2str(_tokenId & PACK_INDEX),
                    uint2str(tokenIncludeBanace[includeBalId]),
                    ".json"
                )
            );
    }

    // cannot be used to test existence, will return a uri for non existing tokenId
    function uri(uint256 _tokenId) public view returns (string memory) {
        return toFullURI(metadataHash[_tokenId & URI_ID], _tokenId);
    }

    function tokenURI(uint256 _tokenId) public view returns (string memory) {
        require(owners[_tokenId] != address(0)); 
        return toFullURI(metadataHash[_tokenId & URI_ID], _tokenId);
    }

    bytes32 private constant base32Alphabet = 0x6162636465666768696A6B6C6D6E6F707172737475767778797A323334353637;
    // solium-disable-next-line security/no-assign-params
    function hash2base32(bytes32 _hash)
        private
        pure
        returns (string memory _uintAsString)
    {
        uint256 _i = uint256(_hash);
        uint256 k = 52;
        bytes memory bstr = new bytes(k);
        bstr[--k] = base32Alphabet[uint8((_i % 8) << 2)]; // uint8 s = uint8((256 - skip) % 5);  // (_i % (2**s)) << (5-s)
        _i /= 8;
        while (k > 0) {
            bstr[--k] = base32Alphabet[_i % 32];
            _i /= 32;
        }
        return string(bstr);
    }

    // solium-disable-next-line security/no-assign-params
    function uint2str(uint256 _i)
        private
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }

        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }

        bytes memory bstr = new bytes(len);
        uint256 k = len - 1;
        while (_i != 0) {
            bstr[k] = bytes1(uint8(48 + (_i % 10)));
            if(k != 0){
                k--;
            } 
            _i /= 10;
        }

        return string(bstr);
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    function supportsInterface(bytes4 id) external pure returns (bool) {
        return
            id == 0x01ffc9a7 || //ERC165
            id == 0xd9b67a26 || // ERC1155
            id == 0x80ac58cd || // ERC721
            id == 0x5b5e139f || // ERC721 metadata
            id == 0x0e89341c; // ERC1155 metadata
    }

    ///////////////////////////////////////// INTERNAL //////////////////////////////////////////////
    
    function checkIsERC1155Receiver(address _contract)
        internal
        view
        returns (bool)
    {
        bool success;
        bool result;
        bytes memory call_data = abi.encodeWithSelector(
            ERC165ID,
            ERC1155_IS_RECEIVER
        );
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let call_ptr := add(0x20, call_data)
            let call_size := mload(call_data)
            let output := mload(0x40) // Find empty storage location using "free memory pointer"
            mstore(output, 0x0)
            success := staticcall(
                10000,
                _contract,
                call_ptr,
                call_size,
                output,
                0x20
            ) // 32 bytes
            result := mload(output)
        }
        // (10000 / 63) "not enough for supportsInterface(...)" // consume all gas, so caller can potentially know that there was not enough gas
        assert(gasleft() > 158);
        return success && result;
    }

    function _checkERC1155AndCallSafeTransfer(
        address _operator,
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes memory _data,
        bool erc721,
        bool erc721Safe
    ) internal returns (bool) {
        if (!_to.isContract()) {
            return true;
        }
        if (erc721) {
            if (!checkIsERC1155Receiver(_to)) {
                if (erc721Safe) {
                    return
                        _checkERC721AndCallSafeTransfer(
                            _operator,
                            _from,
                            _to,
                            _id,
                            _data
                        );
                } else {
                    return true;
                }
            }
        }
        return
            ERC1155TokenReceiver(_to).onERC1155Received(
                    _operator,
                    _from,
                    _id,
                    _value,
                    _data
            ) == ERC1155_RECEIVED;
    }

    function _checkERC1155AndCallSafeBatchTransfer(
        address _operator,
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _values,
        bytes memory _data
    ) internal returns (bool) {
        if (!_to.isContract()) {
            return true;
        }
        bytes4 retval = ERC1155TokenReceiver(_to).onERC1155BatchReceived(
            _operator,
            _from,
            _ids,
            _values,
            _data
        );
        return (retval == ERC1155_BATCH_RECEIVED);
    }

    function _checkERC721AndCallSafeTransfer(
        address _operator,
        address _from,
        address _to,
        uint256 _id,
        bytes memory _data
    ) internal returns (bool) {
        return (ERC721TokenReceiver(_to).onERC721Received(
                _operator,
                _from,
                _id,
                _data
            ) ==
            ERC721_RECEIVED);
    }

    //Extract 
    function _burnERC1155(
        address _operator,
        address _from,
        uint256 _tokenId,
        uint32 _amount
    ) internal {
        (uint256 bin, uint256 index) = (_tokenId).getTokenBinIndex();
        packedTokenBalance[_from][bin] = packedTokenBalance[_from][bin]
            .updateTokenBalance(index, _amount, ObjectLib32.Operations.SUB);
        emit TransferSingle(_operator, _from, address(0), _tokenId, _amount);
    }

    function extractERC721(uint256 _tokenId, address _to)
        external
        returns (uint256 newTokenId)
    {
        return _extractERC721From(msg.sender, msg.sender, _tokenId, _to);
    }

    function _extractERC721From(address _operator, address _sender, uint256 _tokenId, address _to)
        internal
        returns (uint256 newTokenId)
    {
        require(_to != address(0));
        require(_tokenId & IS_NFT == 0);
        uint256 includeBalId = _tokenId & NOT_NFT_INDEX;
        uint32 _collectionIndex = nextCollectionIndex[_tokenId];
        _burnERC1155(_operator, _sender, _tokenId, 1);
        newTokenId = _tokenId +
            IS_NFT +
            (_collectionIndex) *
            2**(256 - 160 - 1 - 32);
        nextCollectionIndex[_tokenId] = _collectionIndex + 1;
        _mint(
            metadataHash[_tokenId & URI_ID],
            1,
            _operator,
            _to,
            newTokenId,
            tokenIncludeBanace[includeBalId],
            "",
            true
        );
    }
}

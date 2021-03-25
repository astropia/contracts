// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import { Origin } from "./lib/Origin.sol";
import "./interface/ERC1155MixedFungible.sol";

contract Astropia is ERC1155MixedFungible
{
    using SafeMath for uint256;
    using Address for address;

    uint256 constant private MINER_MASK = uint256(uint16(~0)) << 128;

    address payable public god;

    mapping (address => bool) public isGameZone;
    mapping (address => uint16) public tokenMiner;
    mapping (uint256 => bool) internal _legalToken;

    mapping (uint256 => mapping (uint8 => uint160)) internal _metadata;

    constructor() {
        god = msg.sender;
    }

    modifier onlyGod() {
        require(msg.sender == god);
        _;
    }

    modifier onlyInGameZone() {
        require(isGameZone[msg.sender]);
        _;
    }

    modifier onlyByMiner() {
        require(tokenMiner[msg.sender] > 0);
        _;
    }

    function metadataOf(uint256 _nftId, uint8 _mIndex) view public returns (uint160) {
        return _metadata[_nftId][_mIndex];
    }

    function multiMetadataOf(uint256 _nftId, uint8[] memory _mIndex) view public returns (uint160[] memory list) {
        list = new uint160[](_mIndex.length);
        mapping (uint8 => uint160) storage allData = _metadata[_nftId];
        for (uint256 i = 0; i < _mIndex.length; i++) {
            list[i] = allData[_mIndex[i]];
        }
    }

    function isLegalToken(uint256 _id) view public returns (bool) {
        return _legalToken[getBaseType(_id)];
    }

    function setGameZone(address _addr, bool _states) external onlyGod {
        isGameZone[_addr] = _states;
    }

    function setLegalToken(uint256 _tokenType, bool _states) external onlyGod {
        require(getBaseType(_tokenType) == _tokenType);
        _legalToken[_tokenType] = _states;
    }

    function setFactory(address _addr, uint16 _index) external onlyGod {
        tokenMiner[_addr] = _index;
    }

    function mintNFT(address _to, uint256 _tokenId) external onlyByMiner returns (uint256) {
        require(isNonFungibleItem(_tokenId));
        require(isLegalToken(_tokenId));

        uint256 nfType = getBaseType(_tokenId);
        require(nfType != _tokenId);

        require(_tokenId & MINER_MASK == 0);
        uint256 tokenIdWithMiner = _tokenId | uint256(tokenMiner[msg.sender]) << 128;
        require(_nfOwners[tokenIdWithMiner] == address(0));

        _transferNonFungibleToken(address(0), _to, tokenIdWithMiner, 1);

        _metadata[_tokenId][254] = uint160(msg.sender);

        emit TransferSingle(msg.sender, address(0), _to, tokenIdWithMiner, 1);

        if (_to.isContract()) {
            _doSafeTransferAcceptanceCheck(msg.sender, address(0), _to, tokenIdWithMiner, 1, "");
        }

        return tokenIdWithMiner;
    }

    function mintFT(address _to, uint256 _tokenId, uint256 _amount) external onlyByMiner {
        require(isFungible(_tokenId));
        require(isLegalToken(_tokenId));

        balances[_tokenId][_to] = balances[_tokenId][_to].add(_amount);

        emit TransferSingle(msg.sender, address(0), _to, _tokenId, _amount);

        if (_to.isContract()) {
            _doSafeTransferAcceptanceCheck(msg.sender, address(0), _to, _tokenId, _amount, "");
        }
    }

    function setOriginMetadata(uint256 _nftId, uint160 _data) external {
        mapping (uint8 => uint160) storage metadata = _checkMetadata();
        require(msg.sender == address(metadata[254]));
        metadata[0] = _data;
    }

    function setMetadata(uint256 _nftId, uint8 _mIndex, uint160 _data) external onlyInGameZone {
        require(_mIndex > 0 && _mIndex < 254);
        mapping (uint8 => uint160) storage metadata = _checkMetadata();
        metadata[_mIndex] = _data;
    }

    function setLockMetadata(uint256 _nftId, bool _lock) external onlyInGameZone {
        mapping (uint8 => uint160) storage metadata = _checkMetadata();
        metadata[255] = _lock ? uint160(msg.sender) : 0;
    }

    function allNonFungibleOf(address _owner, uint256 _type) external view returns (uint256[] memory) {
        uint256[] storage tokens = _nft[_owner][_type];
        return tokens;
    }

    function _checkMetadata(uint256 _nftId) internal returns (mapping (uint8 => uint160) storage metadata) {
        require(isNonFungibleItem(_nftId));
        require(_nfOwners[_nftId] != address(0));
        metadata = _metadata[_nftId];
        require(metadata[255] == 0 || metadata[255] == uint160(msg.sender));
    }
}

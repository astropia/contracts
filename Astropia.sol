// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import { Origin } from "./lib/Origin.sol";
import "./interface/ERC1155MixedFungible.sol";

contract Astropia is ERC1155MixedFungible
{
    using SafeMath for uint256;
    using Address for address;

    uint256 constant MINER_MASK = uint256(uint16(~0)) << 128;

    address payable public god;

    mapping (address => bool) public isGameZone;
    mapping (address => uint16) public tokenMiner;
    mapping (uint128 => bool) public isLegalToken;

    // TODO: Metadata

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

    function setGameZone(address _addr, bool _states) external onlyGod {
        isGameZone[_addr] = _states;
    }

    function setLegalToken(uint128 _tokenType, bool _states) external onlyGod {
        isLegalToken[_tokenType] = _states;
    }

    function setFactory(address _addr, uint16 _index) external onlyGod {
        tokenMiner[_addr] = _index;
    }

    function mintNFT(address _to, uint256 _tokenId) external onlyByMiner {
        require(isNonFungible(_tokenId));
        // require(_nfOwners[_tokenId] == address(0));

        uint256 nfType = getNonFungibleBaseType(_tokenId);
        require(nfType != _tokenId);

        require(_tokenId & MINER_MASK == 0);
        uint256 tokenIdWithMiner = _tokenId | tokenMiner[msg.sender] << 128;

        _transferNonFungibleToken(address(0), _to, tokenIdWithMiner, 1);

        emit TransferSingle(msg.sender, address(0), _to, tokenIdWithMiner, 1);

        if (_to.isContract()) {
            _doSafeTransferAcceptanceCheck(msg.sender, address(0), _to, tokenIdWithMiner, 1, "");
        }
    }

    function mintFT(address _to, uint256 _tokenId, uint256 _amount) external onlyByMiner {
        require(isFungible(_tokenId));

        balances[_tokenId][_to] = balances[_tokenId][_to].add(_amount);

        emit TransferSingle(msg.sender, address(0), _to, _tokenId, _amount);

        if (_to.isContract()) {
            _doSafeTransferAcceptanceCheck(msg.sender, address(0), _to, _tokenId, _amount, "");
        }
    }

    function allNonFungibleOf(address _owner, uint256 _type) external view returns (uint256[] memory) {
        uint256[] storage tokens = _nft[_owner][_type];
        return tokens;
    }
}

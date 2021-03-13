// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import { Origin } from "./lib/Origin.sol";
import "./interface/ERC1155MixedFungible.sol";

contract Astropia is ERC1155MixedFungible
{
    using SafeMath for uint256;
    using Address for address;

    address payable public god;

    mapping (address => bool) public isGameZone;
    mapping (address => bool) public isFactory;
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

    modifier onlyByFactory() {
        require(isFactory[msg.sender]);
        _;
    }

    function setGameZone(address _addr, bool _states) external onlyGod {
        isGameZone[_addr] = _states;
    }

    function setLegalToken(uint128 _tokenType, bool _states) external onlyGod {
        isLegalToken[_tokenType] = _states;
    }

    function setFactory(address _addr, bool _states) external onlyGod {
        isFactory[_addr] = _states;
    }

    function mintNFT(address _to, uint256 _tokenId) external onlyByFactory {
        require(isNonFungible(_tokenId));
        // require(_nfOwners[_tokenId] == address(0));

        uint256 nfType = getNonFungibleBaseType(_tokenId);
        require(nfType != _tokenId);

        _transferNonFungibleToken(address(0), _to, _tokenId, 1);

        emit TransferSingle(msg.sender, address(0), _to, _tokenId, 1);

        if (_to.isContract()) {
            _doSafeTransferAcceptanceCheck(msg.sender, address(0), _to, _tokenId, 1, "");
        }
    }

    function mintFT(address _to, uint256 _tokenId, uint256 _amount) external onlyByFactory {
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

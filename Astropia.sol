// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import { Origin } from "./lib/Origin.sol";
import { ERC721 } from "./interface/ERC721.sol";

contract Astropia is ERC721 {
  address payable public god;

  mapping (address => bool) public gameZone;

  struct Card {
    uint256 balance;
    uint256 exp;
    address beingUsedBy;
    uint256 usingId;
  }
  mapping(uint256 => Card) _cards;

  constructor() {
    god = msg.sender;
  }

  modifier onlyGod() {
    require(msg.sender == god);
    _;
  }

  modifier onlyInGameZone() {
    require(gameZone[msg.sender]);
    _;
  }

  function allCardsOf (address _player) public view returns (
    uint256[] memory cards,
    uint256[] memory usingIds
  ) {
    uint256[] storage tokens = _tokens[_player];
    uint256 l = tokens.length;
    cards = new uint256[](l);
    usingIds = new uint256[](l);
    for (uint256 i = 0; i < l; i++) {
      uint256 cID = tokens[i];
      cards[i] = cID;
      usingIds[i] = _cards[cID].usingId;
    }
  }

  function cardInfo (uint256 _cardID) public view returns (
    address owner,
    uint256 balance,
    uint256 exp,
    address beingUsedBy,
    uint256 usingId
  ) {
    owner = _tokenOwner[_cardID];
    Card storage card = _cards[_cardID];
    balance = card.balance;
    exp = card.exp;
    beingUsedBy = card.beingUsedBy;
    usingId = card.usingId;
  }

  function cardBufferOf (uint256 _cardID) public view returns (uint256) {
    Card storage card = _cards[_cardID];
    return card.exp + card.balance / 1e16;
  }

  function setGameZone(address _addr, bool _states) external onlyGod {
    gameZone[_addr] = _states;
  }

  function mint(address _player, uint256 _tokenId) external onlyInGameZone {
    require(_tokenOwner[_tokenId] == address(0));

    uint256[] storage tokens = _tokens[_player];
    tokens.push(_tokenId);
    _tokenOwner[_tokenId] = _player;

    emit Transfer(address(0), _player, _tokenId);
  }

  function work(uint256 _cardID, address _beingUsedBy, uint256 _usingId) external onlyInGameZone {
    Card storage card = _cards[_cardID];
    require(card.usingId == 0);
    card.beingUsedBy = _beingUsedBy;
    card.usingId = _usingId;
  }

  function workEnd(uint256 _cardID, uint256 exp) external onlyInGameZone {
    Card storage card = _cards[_cardID];
    card.exp += exp;
    card.beingUsedBy = address(0);
    card.usingId = 0;
  }
}

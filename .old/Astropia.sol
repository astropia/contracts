// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import { Origin } from "../lib/Origin.sol";
import { ERC721 } from "../interface/ERC721.sol";

library Math {
  // TODO
  function energy(uint256 x) public pure returns (uint256) {
    return x;
  }
}

contract Astropia {
  using Math for uint256;

  uint256 constant CARD_PRICE = 5e20;
  bytes private constant zeroBytes = new bytes(0x00);

  address payable public god;
  Origin public origin;

  mapping (address => bool) public whitelist;

  struct Player {
    uint256 cardDrawingCount;
  }
  mapping (address => Player) internal _players;
  mapping (address => uint256) internal _playersCardsCount;
  mapping (address => mapping(uint256 => uint256)) internal _playersCards;
  mapping (address => mapping(uint256 => uint256)) internal _playersCardsIndex;

  struct Crystal {
    uint256 amount;
    uint256 lastMiningTime;
    uint256 investment;
  }
  mapping (address => Crystal) internal _crystals;

  struct Card {
    uint256 balance;
    uint256 exp;
    address workAt;
    uint256 workID;
  }
  mapping(uint256 => Card) _cards;

  uint256 public tokenCount;
  mapping (uint256 => address) internal _tokenOwner;

  constructor(Origin _o) {
    god = msg.sender;
    origin = _o;
    origin.random(zeroBytes);
  }

  modifier onlyGod() {
    require(msg.sender == god);
    _;
  }

  modifier onlyWhitelist() {
    require(whitelist[msg.sender]);
    _;
  }

  function crystalOf (address _player) public view returns (uint256 amount, uint256 investment) {
    Crystal storage c = _crystals[_player];
    require(block.timestamp > c.lastMiningTime);
    amount = c.amount + (block.timestamp - c.lastMiningTime) * c.investment.energy();
    investment = c.investment;
  }

  function allCardsOf (address _player) public view returns (
    uint256[] memory cards,
    uint256[] memory workIDs
  ) {
    uint256 max = _playersCardsCount[_player];
    mapping(uint256 => uint256) storage c = _playersCards[_player];
    cards = new uint256[](max);
    workIDs = new uint256[](max);
    for (uint256 i = 0; i < max; i++) {
      uint256 cID = c[i];
      cards[i] = cID;
      workIDs[i] = _cards[cID].workID;
    }
  }

  function cardInfo (uint256 _cardID) public view returns (
    address owner,
    uint256 balance,
    uint256 exp,
    address workAt,
    uint256 workID
  ) {
    owner = _tokenOwner[_cardID];
    Card storage card = _cards[_cardID];
    balance = card.balance;
    exp = card.exp;
    workAt = card.workAt;
    workID = card.workID;
  }

  function cardBufferOf (uint256 _cardID) public view returns (uint256) {
    Card storage card = _cards[_cardID];
    return card.exp + card.balance / 1e16;
  }

  function updateCrystalOf (address _player) internal returns (Crystal storage) {
    Crystal storage c = _crystals[_player];
    uint256 ts = block.timestamp;
    require(ts > c.lastMiningTime);
    c.amount += (ts - c.lastMiningTime) * c.investment.energy();
    c.lastMiningTime = ts;
    return c;
  }

  function setWhitelist(address _addr, bool _states) external onlyGod {
    whitelist[_addr] = _states;
  }

  function invest() public payable {
    Crystal storage c = updateCrystalOf(msg.sender);
    c.investment += msg.value;
  }

  function divest(uint256 _amount) external {
    Crystal storage c = updateCrystalOf(msg.sender);
    require(c.investment >= _amount);
    c.investment -= _amount;
    msg.sender.transfer(_amount);
  }

  function mint(uint8 _type) external {
    Crystal storage c = updateCrystalOf(msg.sender);
    require(_type > 0 && _type < 5);
    uint256 price = _type * CARD_PRICE;
    require(c.amount >= price);
    c.amount -= price;
    _mint(_type, msg.sender);
  }

  function charge(uint256 _cardID) external payable {
    Card storage card = _cards[_cardID];
    require(card.workAt == address(0));
    card.balance += msg.value;
  }

  function takeBackEnergy(uint256 _cardID, uint256 _amount) external {
    require(_tokenOwner[_cardID] == msg.sender);
    Card storage card = _cards[_cardID];
    require(card.workAt == address(0));
    require(_amount <= card.balance);
    card.balance -= _amount;
    msg.sender.transfer(_amount);
  }

  function ownerOf(uint256 _cardID) public view returns (address) {
    return _tokenOwner[_cardID];
  }

  function work(uint256 _cardID, address _workAt, uint256 _workID) external onlyWhitelist {
    Card storage card = _cards[_cardID];
    require(card.workID == 0);
    card.workAt = _workAt;
    card.workID = _workID;
  }

  function workEnd(uint256 _cardID, uint256 exp) external onlyWhitelist {
    Card storage card = _cards[_cardID];
    card.exp += exp;
    card.workAt = address(0);
    card.workID = 0;
  }

  function _mint(uint256 _type, address _player) internal {
    uint256 tokenID = origin.random(abi.encode(_player));

    uint256 lucky = tokenID & 0xff;
    lucky = lucky * _type / (_type + 1);

    uint256 speed = tokenID >> 8 & 0xff;
    speed = speed * _type * 5 / (_type + 1) / 4;
    speed = (speed * speed * speed) >> 16;

    tokenID = tokenID & ~uint256(0xffffffff) | _type << 16 | speed << 8 | lucky;

    require(_tokenOwner[tokenID] == address(0));
    _tokenOwner[tokenID] = _player;
    tokenCount++;
    _players[_player].cardDrawingCount ++;

    uint256 i = _playersCardsCount[_player]++;
    _playersCards[_player][i] = tokenID;
    _playersCardsIndex[_player][tokenID] = i;

    // emit Transfer(address(0), _player, tokenID);
  }

  receive() external payable {
    invest();
  }

  // ERC721
  function transferFrom(address _from, address _to, uint256 _tokenId) external payable {
    require(ownerOf(_tokenId) == _from);
    require(_from != address(0));
    require(_to != address(0));

    Card storage card = _cards[_tokenId];
    require(card.workAt == address(0));

    uint256 o = _playersCardsIndex[_from][_tokenId];
    _playersCardsCount[_from]--;
    uint256 tail = _playersCards[_from][_playersCardsCount[_from]];
    _playersCards[_from][o] = tail;
    _playersCardsIndex[_from][tail] = o;

    uint256 i = _playersCardsCount[_to]++;
    _playersCards[_to][i] = _tokenId;
    _playersCardsIndex[_to][_tokenId] = i;

    _tokenOwner[_tokenId] = _to;
  }
}

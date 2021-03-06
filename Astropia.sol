// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import { Origin } from "./lib/Origin.sol";
import { ERC721 } from "./interface/ERC721.sol";

library Math {
  // TODO
  function energy(uint256 x) public pure returns (uint256) {
    return x;
  }
}

contract Astropia {
  using Math for uint256;

  uint256 constant CARD_PRICE = 500000000;
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

  struct Crystal {
    uint256 amount;
    uint256 lastMiningtime;
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

  function crystalOf (address _player) public view returns (uint256) {
    Crystal storage c = _crystals[_player];
    require(block.timestamp > c.lastMiningtime);
    return c.amount + (block.timestamp - c.lastMiningtime) * c.investment.energy();
  }

  function allCardsOf (address _player) public view returns (bytes32[] memory cards) {
    uint256 max = _playersCardsCount[_player];
    mapping(uint256 => uint256) storage c = _playersCards[_player];
    cards = new bytes32[](max);
    for (uint256 i = 0; i < max; i++) {
      cards[i] = bytes32(c[i]);
    }
  }

  function updateCrystalOf (address _player) internal returns (Crystal storage) {
    Crystal storage c = _crystals[_player];
    uint256 ts = block.timestamp;
    require(ts > c.lastMiningtime);
    c.amount += (ts - c.lastMiningtime) * c.investment.energy();
    c.lastMiningtime = ts;
    return c;
  }

  function setwhitelist(address _addr, bool _states) external onlyGod {
    whitelist[_addr] = _states;
  }

  function invest() external payable {
    Crystal storage c = updateCrystalOf(msg.sender);
    c.investment += msg.value;
  }

  function divest(uint256 _amount) external {
    Crystal storage c = updateCrystalOf(msg.sender);
    require(c.investment > _amount);
    c.investment -= _amount;
    msg.sender.transfer(_amount);
  }

  function mint(uint8 _type) external {
    Crystal storage c = updateCrystalOf(msg.sender);
    require(_type > 0 && _type < 4);
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

  function work(uint256 _cardID, uint256 _exp; address _workAt, uint256 _workID) external onlyWhitelist {
    require(_tokenOwner[_cardID] != address(0));
    Card storage card = _cards[_cardID];
    card.exp += _exp;
    card.workAt = _workAt;
    card.workID = _workID;
  }

  function _mint(uint256 _type, address _player) internal {
    uint256 tokenID = origin.random(abi.encode(_player));

    uint256 lucky = tokenID & 0xff;
    lucky = lucky * _type / (_type + 1);

    uint256 speed = tokenID >> 8 & 0xff;
    speed = speed * _type * 4 / (_type + 1) / 3;
    speed = (speed * speed * speed) >> 16;

    tokenID = tokenID & ~uint256(0xffffff) | speed << 8 | lucky;

    require(_tokenOwner[tokenID] == address(0));
    _tokenOwner[tokenID] = _player;
    tokenCount++;
    _players[_player].cardDrawingCount ++;

    uint256 i = _playersCardsCount[_player]++;
    _playersCards[_player][i] = tokenID;

    // emit Transfer(address(0), _player, tokenID);
  }
}

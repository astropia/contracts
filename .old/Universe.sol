// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import { Origin } from "../lib/Origin.sol";
import { Astropia } from "./Astropia.sol";

library CardParser {
  function lucky(uint256 id) public pure returns (uint256) {
    return id & 0xff;
  }
  function speed(uint256 id) public pure returns (uint256) {
    return id >> 8 & 0xff;
  }
}

contract Universe {
  using CardParser for uint256;

  bytes private constant zeroBytes = new bytes(0x00);

  address payable public god;
  Origin public origin;

  struct Exploration {
    bool ongoing;
    uint256 salt;
    uint256 leader;
    Astropia leaderFrom;
    uint256 member;
    Astropia memberFrom;

    uint256 aim;
    uint256 startAt;
  }

  uint256 public totalItemCount = 100;
  uint256 public itemCount;

  mapping(address => uint256[]) internal _items;

  uint256 internal _pendingExplorationsCount;
  mapping(uint256 => uint256) internal _pendingExplorations;
  mapping(uint256 => uint256) internal _pendingExplorationsIndex;

  mapping(uint256 => Exploration) internal _explorations;

  mapping(Astropia => bool) public whitelist;

  constructor(Origin _o) {
    god = msg.sender;
    origin = _o;
    origin.random(zeroBytes);
  }

  modifier onlyGod() {
    require(msg.sender == god);
    _;
  }

  function setTrustContract(Astropia _addr, bool _states) external onlyGod {
    whitelist[_addr] = _states;
  }

  function createExploration(Astropia _astropia, uint256 _cardID, uint256 _aim) external {
    require(whitelist[_astropia]);
    require(_astropia.ownerOf(_cardID) == msg.sender);

    uint256 eID = origin.random(abi.encode(_cardID));
    Exploration storage e = _explorations[eID];

    require(e.leader == 0);

    e.leader = _cardID;
    e.leaderFrom = _astropia;
    e.aim = _aim;

    _pendingExplorations[_pendingExplorationsCount] = eID;
    _pendingExplorationsIndex[eID] = _pendingExplorationsCount;
    _pendingExplorationsCount++;

    _astropia.work(_cardID, address(this), eID);
  }

  function joinExploration(Astropia _astropia, uint256 _cardID, uint256 _eID) external {
    require(whitelist[_astropia]);
    require(_astropia.ownerOf(_cardID) == msg.sender);

    Exploration storage e = _explorations[_eID];

    uint256 leader = e.leader;
    require(leader != 0);
    require(leader != _cardID);

    e.member = _cardID;
    e.memberFrom = _astropia;
    e.salt = origin.random(abi.encode(leader, _cardID));
    e.ongoing = true;
    e.startAt = block.timestamp;

    uint256 index = _pendingExplorationsIndex[_eID];

    _pendingExplorationsCount--;
    _pendingExplorations[index] = _pendingExplorations[_pendingExplorationsCount];

    _astropia.work(_cardID, address(this), _eID);
  }

  function exploration(uint256 _eID) external view returns (
    bool ongoing,
    uint256 salt,
    uint256 leader,
    uint256 member,
    uint256 aim,
    uint256 progress
  ) {
    Exploration storage e = _explorations[_eID];
    ongoing = e.ongoing;
    salt = e.salt;
    leader = e.leader;
    member = e.member;
    aim = e.aim;
    progress = 0;
    uint256 ts = block.timestamp;
    if (e.member != 0 && ts > e.startAt) {
      progress = (ts - e.startAt) * (leader.speed() + member.speed());
    }
    if (progress > aim) {
      progress = aim;
    }
  }
  
  function itemsOf(address _player) external view returns (uint256[] memory) {
    return _items[_player];
  }
  
  function allPendingExps() external view returns (uint256[] memory es) {
    es = new uint256[](_pendingExplorationsCount);
    for (uint256 i = 0; i < _pendingExplorationsCount; i++) {
        es[i] = _pendingExplorations[i];
    }
  }
  
  function allPendingExpsDetail() external view returns (
    uint256[] memory es,
    uint256[] memory aims,
    uint256[] memory leaders
  ) {
    es = new uint256[](_pendingExplorationsCount);
    aims = new uint256[](_pendingExplorationsCount);
    leaders = new uint256[](_pendingExplorationsCount);
    for (uint256 i = 0; i < _pendingExplorationsCount; i++) {
      uint256 eID = _pendingExplorations[i];
      es[i] = eID;
      Exploration storage e = _explorations[eID];
      aims[i] = e.aim;
      leaders[i] = e.leader;
    }
  }

  function end(uint256 _eID) external {
    Exploration storage e = _explorations[_eID];
    require(e.ongoing);
    bool isLeader = false;
    bool checked = false;

    address leaderAddr = e.leaderFrom.ownerOf(e.leader);
    address memberAddr = e.memberFrom.ownerOf(e.member);

    if (leaderAddr == msg.sender) {
      isLeader = true;
      checked = true;
    } else if (memberAddr == msg.sender) {
      checked = true;
    }
    require(checked);
    uint256 ts = block.timestamp;
    require(ts > e.startAt);
    uint256 progress = (ts - e.startAt) * (e.leader.speed() + e.member.speed());
    require(progress >= e.aim);

    _items[leaderAddr].push(itemCount++);
    _items[memberAddr].push(itemCount++);

    e.ongoing = false;
    e.leaderFrom.workEnd(e.leader, e.aim);
    e.memberFrom.workEnd(e.member, e.aim);
  }

  function rageEnd(uint256 _eID) external {
    Exploration storage e = _explorations[_eID];
    require(e.ongoing);
    require(e.leaderFrom.ownerOf(e.leader) == msg.sender || e.memberFrom.ownerOf(e.member) == msg.sender);
    
    e.ongoing = false;
    e.leaderFrom.workEnd(e.leader, 0);
    e.memberFrom.workEnd(e.member, 0);
  }
}

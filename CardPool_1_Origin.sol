// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import { Origin } from "./lib/Origin.sol";
import { Astropia } from "./Astropia.sol";

library Math {
    // TODO
    function energy(uint256 x) public pure returns (uint256) {
        return x;
    }
}

contract CardPool_1 {
    using Math for uint256;

    uint256 constant CARD_PRICE = 5e20;
    uint256 constant MASK        = 0x0000000000000000000000000000000000000011111111111111111111111111;
    uint256 constant CARD_POOL_1 = 0x10000000000000417374726f7069617200010000000000000000000000000000;

    Origin public origin;
    Astropia public astropia;

    mapping (address => uint256) internal _cardDrawingCounts;

    struct Crystal {
        uint256 amount;
        uint256 lastMiningTime;
        uint256 investment;
    }
    mapping (address => Crystal) internal _crystals;

    constructor(Origin _o, Astropia _a) {
        origin = _o;
        astropia = _a;
        origin.random("");
    }

    function crystalOf (address _player) public view returns (uint256 amount, uint256 investment) {
        Crystal storage c = _crystals[_player];
        require(block.timestamp > c.lastMiningTime);
        amount = c.amount + (block.timestamp - c.lastMiningTime) * c.investment.energy();
        investment = c.investment;
    }

    function invest() public payable {
        Crystal storage c = _updateCrystalOf(msg.sender);
        c.investment += msg.value;
    }

    function divest(uint256 _amount) external {
        Crystal storage c = _updateCrystalOf(msg.sender);
        require(c.investment >= _amount);
        c.investment -= _amount;
        msg.sender.transfer(_amount);
    }

    function mint(uint16 _type) external {
        Crystal storage c = _updateCrystalOf(msg.sender);
        require(_type > 0 && _type < 5);
        uint256 price = _type * CARD_PRICE;
        require(c.amount >= price);
        c.amount -= price;
        _cardDrawingCounts[msg.sender]++;
        _mint(_type, msg.sender);
    }

    function _mint(uint16 _type, address _player) internal {
        uint256 tokenId = origin.random(abi.encode(_player));

        tokenId = tokenId & MASK | CARD_POOL_1 | _type << 104;

        astropia.mintNFT(_player, tokenId);
    }

    function _updateCrystalOf (address _player) internal returns (Crystal storage) {
        Crystal storage c = _crystals[_player];
        uint256 ts = block.timestamp;
        require(ts > c.lastMiningTime);
        c.amount += (ts - c.lastMiningTime) * c.investment.energy();
        c.lastMiningTime = ts;
        return c;
    }

    receive() external payable {
        invest();
    }
}

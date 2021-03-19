// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import { Origin } from "./lib/Origin.sol";
import { Astropia } from "./Astropia.sol";

library Math {
    // TODO
    function energy(uint256 x) public pure returns (uint256) {
        return x;
    }
}

contract CardPool_1
{
    using Math for uint256;

    uint256 constant private MASK        = 0x0000000000000000000000000000000000ffffffffffffffffffffffffffffff;
    uint256 constant private CARD_POOL_1 = 0x8000000000417374726f70696172000000000000000000000000000000000000;

    address payable public god;

    mapping (uint8 => uint256) public cardPrice;
    mapping (uint8 => uint256) public cardFoundation;

    Origin public originLib;
    Astropia public astropia;

    mapping (address => uint256) internal _cardDrawingCounts;

    struct Crystal {
        uint256 amount;
        uint256 lastMiningTime;
        uint256 investment;
    }
    mapping (address => Crystal) internal _crystals;

    event Card (uint8 indexed _type, uint256 _price, uint256 _foundation);

    constructor(Origin _o, Astropia _a) {
        god = msg.sender;
        originLib = _o;
        astropia = _a;
        originLib.random("");
    }

    modifier onlyGod() {
        require(msg.sender == god);
        _;
    }

    function crystalOf (address _player) public view returns (uint256 amount, uint256 investment) {
        Crystal storage c = _crystals[_player];
        require(block.timestamp > c.lastMiningTime);
        amount = c.amount + (block.timestamp - c.lastMiningTime) * c.investment.energy();
        investment = c.investment;
    }

    function setCardInfo (uint8 _type, uint256 _price, uint256 _foundation) external onlyGod {
        cardPrice[_type] = _price;
        cardFoundation[_type] = _foundation;

        emit Card(_type, _price, _foundation);
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

    function mint(uint8 _type) external {
        uint256 price = cardPrice[_type];
        require(price > 0);
        Crystal storage c = _updateCrystalOf(msg.sender);
        require(c.amount >= price);
        c.amount -= price;

        _cardDrawingCounts[msg.sender]++;

        uint256 id = _mint(_type, msg.sender);
        _initMetadata(id, _type);
    }

    function _mint(uint8 _type, address _player) internal returns (uint256) {
        uint256 tokenId = originLib.random(abi.encode(_player));

        tokenId = tokenId & MASK | CARD_POOL_1 | uint256(_type) << 120;

        uint256 newId = astropia.mintNFT(_player, tokenId);
        return newId;
    }

    function _initMetadata(uint256 _id, uint8 _type) internal {
        uint256 f = cardFoundation[_type];
        uint256 r = originLib.random(abi.encode(_id));

        uint256 power = f * uint16(r) / (1 << 16) + f;

        require(uint160(power) == power);
        astropia.updateMetadata(_id, 0, uint160(power));
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

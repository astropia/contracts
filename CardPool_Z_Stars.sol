// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import { Origin } from "./lib/Origin.sol";
import { Astropia } from "./Astropia.sol";

contract CardPool_Z
{
    uint256 constant private MASK        = 0x0000000000000000000000000000000000ffffffffffffffffffffffffffffff;
    uint256 constant private CARD_POOL_Z = 0x8000000000417374726f70696172000000000000000000000000000000000000;

    address payable public god;

    uint256 public cardPrice;
    uint8 public typesCount;
    mapping (address => bool) public whitelist;
    mapping (address => uint256) public holded;

    Origin public originLib;
    Astropia public astropia;

    mapping (address => uint256) internal _cardDrawingCounts;

    event CardPrice (uint256 _price);
    event CardTypesCount (uint256 _price);

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

    function setCardPrice (uint256 _price) external onlyGod {
        cardPrice = _price;
        emit CardPrice(_price);
    }

    function setCardTypesCount (uint8 _count) external onlyGod {
        typesCount = _count;
        emit CardTypesCount(_count);
    }

    function setWhiteList (address _user, bool _pass) external onlyGod {
        whitelist[_user] = _pass;
    }

    function mint() external payable {
        require(typesCount > 0);
        require(msg.value == cardPrice);
        require(whitelist[msg.sender] || holded[msg.sender] + 1 days < block.timestamp);
        holded[msg.sender] = block.timestamp;

        _cardDrawingCounts[msg.sender]++;


        uint256 id = _mint(msg.sender);
        _initMetadata(id);
    }

    function _mint(address _player) internal returns (uint256) {
        uint256 tokenId = originLib.random(abi.encode(_player));
        uint8 t = uint8(tokenId % typesCount);

        tokenId = tokenId & MASK | CARD_POOL_Z | uint256(t) << 120;

        uint256 newId = astropia.mintNFT(_player, tokenId);
        return newId;
    }

    function _initMetadata(uint256 _id) internal {
        uint256 f = 1 << 80;
        uint256 r = originLib.random(abi.encode(_id));

        uint256 power = f * uint16(r) / (1 << 16) + f;

        require(uint160(power) == power);
        astropia.setOriginMetadata(_id, uint160(power));
        astropia.setMetadata(_id, 1, uint160(power));
    }
}

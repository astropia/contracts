// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import { Origin } from "./lib/Origin.sol";
import { Astropia } from "./Astropia.sol";
import { ERC165 } from "./interface/ERC165.sol";
import { ERC1155TokenReceiver } from "./interface/IERC1155TokenReceiver.sol";

library Address
{
    function isNotContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size == 0;
    }
}

contract Spica is ERC1155TokenReceiver, ERC165
{
    using Address for address;

    bytes4 constant private CREATE = 0x81d0974d; // keccak256("CREATE()")
    bytes4 constant private JOIN = 0x725e42cb; // keccak256("JOIN(uint256)")
    bytes4 constant private BACK = 0x2a78c040; // keccak256("BACK()")

    uint256 constant public MAX_EXPLORATION_ROOM_COUNT = 32;

    Origin public originLib;
    Astropia public astropia;

    struct Exploration {
        bool ongoing;
        uint256 salt;
        uint256 leaderId;
        address leaderOwner;
        uint256 memberId;
        address memberOwner;

        uint256 hightstIndex;

        uint256 aim;
        uint256 startAt;
    }

    mapping(uint256 => Exploration) internal _explorations;
    uint256[] internal _explorationQuery;
    uint256 internal _tailOfQuery;

    constructor(Origin _o, Astropia _a) {
        originLib = _o;
        astropia = _a;
        originLib.random("");
    }

    function supportsInterface(bytes4 _interfaceId) override public pure returns (bool) {
        if (_interfaceId == 0x01ffc9a7 || _interfaceId == 0x4e2312e0) {
            return true;
        }
        return false;
    }

    function exploration(uint256 _eID) external view returns (
        bool ongoing,
        uint256 salt,
        uint256 leaderId,
        address leaderOwner,
        uint256 memberId,
        address memberOwner,
        uint256 aim,
        uint256 progress
    ) {
        Exploration storage e = _explorations[_eID];
        ongoing = e.ongoing;
        salt = e.salt;
        leaderId = e.leaderId;
        leaderOwner = e.leaderOwner;
        memberId = e.memberId;
        memberOwner = e.memberOwner;
        aim = e.aim;
        progress = 0;
        uint256 ts = block.timestamp;
        uint256 powerL = astropia.metadataOf(leaderId, 0);
        uint256 powerM = astropia.metadataOf(memberId, 0);
        if (e.memberId != 0 && ts > e.startAt) {
            progress = (ts - e.startAt) * (powerL + powerM);
        }
        if (progress > aim) {
            progress = aim;
        }
    }

    function onERC1155Received(
        address,
        address _from,
        uint256 _id,
        uint256,
        bytes memory _data
    ) override external returns(bytes4) {
        require(_from.isNotContract());
        require(msg.sender == address(astropia), "only accept tokens in Astropia contract");
        // There is no need to check the ownership of the token because the Astropia is always right.

        uint256 l = _data.length;
        bytes4 sign;
        assembly {
            sign := mload(add(_data, 32))
        }

        if (l == 4 && sign == CREATE) {
            _createExploration(_from, _id, 3000);
        } else if (l == 36 && sign == JOIN) {
            uint256 eId;
            assembly {
                eId := mload(add(_data, 36))
            }
            _joinExploration(_from, _id, eId);
        } else {
            revert();
        }

        return 0xf23a6e61;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes memory
    ) override pure external returns(bytes4) {
        revert();
    }

    function pokeRoom(uint256 _eID) external {
        Exploration storage e = _explorations[_eID];
        require(e.leaderOwner == msg.sender);
        require(e.startAt == 0);
        require(e.hightstIndex + MAX_EXPLORATION_ROOM_COUNT < _pendingExplorations.length);

        _pushExpRoom(e, _eId);
    }

    function end(uint256 _eID) external {
        Exploration storage e = _explorations[_eID];
        require(e.ongoing);
        bool isLeader = false;
        bool checked = false;

        if (e.leaderOwner == msg.sender) {
            isLeader = true;
            checked = true;
        } else if (e.memberOwner == msg.sender) {
            checked = true;
        }
        require(checked);
        uint256 ts = block.timestamp;
        require(ts > e.startAt);
        uint256 powerL = astropia.metadataOf(e.leaderId, 0);
        uint256 powerM = astropia.metadataOf(e.memberId, 0);
        uint256 progress = (ts - e.startAt) * (powerL + powerM);
        require(progress >= e.aim);

        // TODO: reward

        e.ongoing = false;

        bytes memory backData = abi.encode(BACK);
        astropia.safeTransferFrom(address(this), e.leaderOwner, e.leaderId, 1, backData);
        astropia.safeTransferFrom(address(this), e.memberOwner, e.memberId, 1, backData);
    }


    function _createExploration(address _owner, uint256 _id, uint256 _aim) internal {
        uint256 eId = originLib.random(abi.encode(_id));
        Exploration storage e = _explorations[eId];

        require(e.leaderId == 0);

        e.leaderId = _id;
        e.leaderOwner = _owner;
        e.aim = _aim;

        _pushExpRoom(e, eId);
    }

    function _joinExploration(address _owner, uint256 _id, uint256 _eId) internal {
        Exploration storage e = _explorations[_eId];

        uint256 leader = e.leaderId;
        require(leader != 0);
        require(leader != _id);
        require(e.startAt = 0);

        e.memberId = _id;
        e.memberOwner = _owner;
        e.salt = originLib.random(abi.encode(leader, _id));
        e.ongoing = true;
        e.startAt = block.timestamp;
    }

    function _pushExpRoom(Exploration storage _e, uint256 _eId) internal {
        _e.hightstIndex = _pendingExplorations.length;
        _pendingExplorations.push(_eId);
        if (_pendingExplorations.length > MAX_EXPLORATION_ROOM_COUNT) {
            _tailOfQuery = _pendingExplorations.length - MAX_EXPLORATION_ROOM_COUNT
        }
    }
}

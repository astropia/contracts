// https://eips.ethereum.org/EIPS/eip-721, http://erc721.org/ 
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

library AddressUtils {
  function isContract(address addr) internal view returns (bool) {
    uint256 size;
    assembly { size := extcodesize(addr) }
    return size > 0;
  }
}

library SafeMath {
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

interface ERC721TokenReceiver {
  /// @notice Handle the receipt of an NFT
  /// @dev The ERC721 smart contract calls this function on the recipient
  ///  after a `transfer`. This function MAY throw to revert and reject the
  ///  transfer. Return of other than the magic value MUST result in the
  ///  transaction being reverted.
  ///  Note: the contract address is always the message sender.
  /// @param _operator The address which called `safeTransferFrom` function
  /// @param _from The address which previously owned the token
  /// @param _tokenId The NFT identifier which is being transferred
  /// @param _data Additional data with no specified format
  /// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
  ///  unless throwing
  function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes memory _data) external returns(bytes4);
}

import { ERC165 } from './ERC165.sol';

contract ERC721 is ERC165 {
  using AddressUtils for address;
  using SafeMath for uint256;

  mapping(address => uint256[]) internal _tokens;

  mapping(uint256 => uint256) internal _tokenIndex;
  mapping(uint256 => address) internal _tokenOwner;

  mapping(address => mapping(address => bool)) internal _approval;
  mapping(uint256 => address) _approvedAccount;

  constructor() {
    _supportedInterfaces[0x80ac58cd] = true;
  }

  modifier isOperator(uint256 _tokenId) {
    address owner = _ownerOf(_tokenId);
    address operator = msg.sender;
    require(operator == owner || _approval[owner][operator] || _approvedAccount[_tokenId] == operator, "no operation permission");
    _;
  }

  /// @dev This emits when ownership of any NFT changes by any mechanism.
  ///  This event emits when NFTs are created (`from` == 0) and destroyed
  ///  (`to` == 0). Exception: during contract creation, any number of NFTs
  ///  may be created and assigned without emitting Transfer. At the time of
  ///  any transfer, the approved address for that NFT (if any) is reset to none.
  event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

  /// @dev This emits when the approved address for an NFT is changed or
  ///  reaffirmed. The zero address indicates there is no approved address.
  ///  When a Transfer event emits, this also indicates that the approved
  ///  address for that NFT (if any) is reset to none.
  event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

  /// @dev This emits when an operator is enabled or disabled for an owner.
  ///  The operator can manage all NFTs of the owner.
  event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

  /// @notice Count all NFTs assigned to an owner
  /// @dev NFTs assigned to the zero address are considered invalid, and this
  ///  function throws for queries about the zero address.
  /// @param _owner An address for whom to query the balance
  /// @return The number of NFTs owned by `_owner`, possibly zero
  function balanceOf(address _owner) external view returns (uint256) {
    require(_owner != address(0));
    return _tokens[_owner].length;
  }

  /// @notice Find the owner of an NFT
  /// @dev NFTs assigned to zero address are considered invalid, and queries
  ///  about them do throw.
  /// @param _tokenId The identifier for an NFT
  /// @return The address of the owner of the NFT
  function ownerOf(uint256 _tokenId) external view returns (address) {
    return _ownerOf(_tokenId);
  }

  /// @notice Transfers the ownership of an NFT from one address to another address
  /// @dev Throws unless `msg.sender` is the current owner, an authorized
  ///  operator, or the approved address for this NFT. Throws if `_from` is
  ///  not the current owner. Throws if `_to` is the zero address. Throws if
  ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
  ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
  ///  `onERC721Received` on `_to` and throws if the return value is not
  ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
  /// @param _from The current owner of the NFT
  /// @param _to The new owner
  /// @param _tokenId The NFT to transfer
  /// @param data Additional data with no specified format, sent in call to `_to`
  function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) isOperator(_tokenId) external payable {
    _safeTransferFrom(_from, _to, _tokenId, data);
  }

  /// @notice Transfers the ownership of an NFT from one address to another address
  /// @dev This works identically to the other function with an extra data parameter,
  ///  except this function just sets data to "".
  /// @param _from The current owner of the NFT
  /// @param _to The new owner
  /// @param _tokenId The NFT to transfer
  function safeTransferFrom(address _from, address _to, uint256 _tokenId) isOperator(_tokenId) external payable {
    _safeTransferFrom(_from, _to, _tokenId, "");
  }

  /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
  ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
  ///  THEY MAY BE PERMANENTLY LOST
  /// @dev Throws unless `msg.sender` is the current owner, an authorized
  ///  operator, or the approved address for this NFT. Throws if `_from` is
  ///  not the current owner. Throws if `_to` is the zero address. Throws if
  ///  `_tokenId` is not a valid NFT.
  /// @param _from The current owner of the NFT
  /// @param _to The new owner
  /// @param _tokenId The NFT to transfer
  function transferFrom(address _from, address _to, uint256 _tokenId) isOperator(_tokenId) external payable {
    _unsafeTransfer(_from, _to, _tokenId);
  }

  /// @notice Change or reaffirm the approved address for an NFT
  /// @dev The zero address indicates there is no approved address.
  ///  Throws unless `msg.sender` is the current NFT owner, or an authorized
  ///  operator of the current owner.
  /// @param _approved The new approved NFT controller
  /// @param _tokenId The NFT to approve
  function approve(address _approved, uint256 _tokenId) external payable {
    address owner = _ownerOf(_tokenId);
    require(msg.sender == owner || _approval[owner][msg.sender], "no operation permission");
    _approvedAccount[_tokenId] = _approved;

    emit Approval(owner, _approved, _tokenId);
  }

  /// @notice Enable or disable approval for a third party ("operator") to manage
  ///  all of `msg.sender`'s assets
  /// @dev Emits the ApprovalForAll event. The contract MUST allow
  ///  multiple operators per owner.
  /// @param _operator Address to add to the set of authorized operators
  /// @param _approved True if the operator is approved, false to revoke approval
  function setApprovalForAll(address _operator, bool _approved) external {
    _approval[msg.sender][_operator] = true;

    emit ApprovalForAll(msg.sender, _operator, _approved);
  }

  /// @notice Get the approved address for a single NFT
  /// @dev Throws if `_tokenId` is not a valid NFT.
  /// @param _tokenId The NFT to find the approved address for
  /// @return The approved address for this NFT, or the zero address if there is none
  function getApproved(uint256 _tokenId) external view returns (address) {
    address owner = _tokenOwner[_tokenId];
    require(owner != address(0), "it is not a valid NFT");
    return _approvedAccount[_tokenId];
  }

  /// @notice Query if an address is an authorized operator for another address
  /// @param _owner The address that owns the NFTs
  /// @param _operator The address that acts on behalf of the owner
  /// @return True if `_operator` is an approved operator for `_owner`, false otherwise
  function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
    return _approval[_owner][_operator];
  }

  function _ownerOf(uint256 _tokenId) internal view returns (address) {
    address owner = _tokenOwner[_tokenId];
    require(owner != address(0), "it is not a valid NFT");
    return owner;
  }

  function _safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) internal {
    _unsafeTransfer(_from, _to, _tokenId);

    if (_to.isContract()) {
      bytes4 returned = ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data);
      require(returned == 0x150b7a02, "receiving contract can not handled correctly");
    }
  }

  function _unsafeTransfer(address _from, address _to, uint256 _tokenId) internal {
    require(_to != address(0));

    _tokenOwner[_tokenId] = _to;
  
    uint256[] storage fromTokens = _tokens[_from];
    uint256[] storage toTokens = _tokens[_to];

    fromTokens[_tokenIndex[_tokenId]] = fromTokens[fromTokens.length - 1];
    fromTokens.pop();

    toTokens.push(_tokenId);
    _tokenIndex[_tokenId] = toTokens.length - 1;

    emit Transfer(_from, _to, _tokenId);

    _approvedAccount[_tokenId] = address(0);
    emit Approval(_to, address(0), _tokenId);
  }
}

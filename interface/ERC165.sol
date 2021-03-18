// https://eips.ethereum.org/EIPS/eip-721, http://erc721.org/ 
// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.8.0;

contract ERC165 {
  mapping(bytes4 => bool) internal _supportedInterfaces;

  constructor() {
    _supportedInterfaces[0x01ffc9a7] = true;
  }

  /// @notice Query if a contract implements an interface
  /// @param interfaceID The interface identifier, as specified in ERC-165
  /// @dev Interface identification is specified in ERC-165. This function
  ///  uses less than 30,000 gas.
  /// @return `true` if the contract implements `interfaceID` and
  ///  `interfaceID` is not 0xffffffff, `false` otherwise
  function supportsInterface(bytes4 interfaceID) virtual external view returns (bool) {
    return _supportedInterfaces[interfaceID];
  }
}

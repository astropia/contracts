// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

contract Origin {
  uint256 private _randomSeed = uint256(keccak256("LetThereBeLight"));

  function random(bytes memory data) external returns (uint256) {
    _randomSeed = uint256(keccak256(abi.encode(data, _randomSeed, tx.origin, gasleft(), block.coinbase)));
    return _randomSeed;
  }
}

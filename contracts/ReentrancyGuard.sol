// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

contract ReentrancyGuard {
  bool private _on = false;

  modifier NoReentrant() {
    require(_on == false);
    _on = true;
    _;
    _on = false;
  }
}

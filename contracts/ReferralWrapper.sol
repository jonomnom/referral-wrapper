// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {Governable} from "./Governable.sol";
import {IReferralStorage} from "./IReferralStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "./ReentrancyGuard.sol";
import {Color} from "./Color.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";

contract ReferralWrapper is ReentrancyGuard, IERC721Receiver {
  // call a minting function on behalf a user
  // transfer funds to this address
  // datastructure to map referrer with referee
  // handle payouts on successful transaction (lets start with ETH)
  //

  address private _owner;
  address[] private _whitelistedTokens = [address(0)];
  mapping(address => mapping(address => uint256)) _referrerToFee; // in ETH
  mapping(address => address) _refereeToReferrer;
  mapping(address => uint256) userToTokenId;
  mapping(address => bool) userToHasBalance;
  event FeeSet(address referrer, address token, uint256 newFee);
  address nftContract;
  modifier onlyOwner() {
    require(msg.sender == _owner, "Not owner");
    _;
  }

  constructor() {
    _owner = msg.sender;
  }

  function setNftContract(address _nftContract) public {
    nftContract = _nftContract;
  }

  // only supports erc20
  function whitelistTokens(address[] memory tokens) public onlyOwner {
    for (uint256 i = 0; i < tokens.length; i++) {
      _whitelistedTokens.push(tokens[i]);
    }
  }

  function deposit() external payable {}

  function withdraw() external onlyOwner {
    payable(msg.sender).transfer(address(this).balance);
    for (uint256 i = 0; i < _whitelistedTokens.length; i++) {
      IERC20 token = IERC20(_whitelistedTokens[i]);
      token.transfer(address(this), token.balanceOf(address(this)));
    }
  }

  //TODO: referrer and referee both get discounts
  function mintNFT(address _referrer) external payable NoReentrant {
    // if the msg.sender has an affiliate in storage or if has affiliate passed into function, then do special fee sharing
    uint256 price = 1 ether;
    require(msg.value == price, "sent eth is not price");
    for (uint256 i = 0; i < _whitelistedTokens.length; i++) {
      address token = _whitelistedTokens[i];
      uint256 fee = _referrerToFee[_referrer][token];
      if (fee > 0) {
        //// check if this contract has enough balance
        require(address(this).balance >= fee, "contract does not have enough to pay affiliate");
        if (token == address(0)) {
          payable(_referrer).transfer(fee);
        } else {
          IERC20(token).transfer(_referrer, fee);
        }
      }
    }
    _refereeToReferrer[msg.sender] = _referrer;
    Color(nftContract).mint{value: price}("blue");
    uint256 totalSupply = Color(nftContract).totalSupply() - 1;
    require(userToHasBalance[msg.sender] == true, "user must have balance"); // willl fail if token id that user minted is zero
    userToHasBalance[msg.sender] == false;
    Color(nftContract).transferFrom(address(this), msg.sender, userToTokenId[msg.sender]);
    userToTokenId[msg.sender] = 0;
  }

  function onERC721Received(
    address _operator,
    address _from,
    uint256 _tokenId,
    bytes calldata _data
  ) external returns (bytes4) {
    //https://github.com/OpenZeppelin/openzeppelin-contracts/blob/a4fc50c501ad078d8705715c4a10ea98c52180fb/contracts/token/ERC721/ERC721.sol#L435
    userToTokenId[tx.origin] = _tokenId;
    userToHasBalance[tx.origin] = true;
    return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")); //???
  }

  function getOwner() public view returns (address) {
    return _owner;
  }

  function getRefereeToReferrer(address _referee) public view returns (address) {
    return _refereeToReferrer[_referee];
  }

  function getWhitelistedTokens() public view returns (address[] memory) {
    return _whitelistedTokens;
  }

  function getFee(address _referrer, address _token) public view returns (uint256) {
    return _referrerToFee[_referrer][_token];
  }

  // _fees maps one to one with the tokens in _whitelistedTokens
  function setFee(address _referrer, uint256[] memory _fees) public onlyOwner {
    for (uint256 i = 0; i < _whitelistedTokens.length; i++) {
      _referrerToFee[_referrer][_whitelistedTokens[i]] = _fees[i];
      emit FeeSet(_referrer, _whitelistedTokens[i], _fees[i]);
    }
  }
}

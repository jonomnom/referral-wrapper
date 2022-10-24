// SPDX-License-Identifier: MIT

// logic flaws
// use require instead of revert
// add zeros to math when dividing
// withdraw function doesn't transfer
// you can approve and transfer in one transaction

pragma solidity ^0.8.7;

contract Math {
  uint256 private _addResult;
  uint256 private _multiplyResult;

  // I am pretty should overflow was fixed in after version 8.0.0
  function _add(uint256 a, uint256 b) internal {
    _addResult = a + b;
  }

  function _multiply(uint256 a, uint256 b) internal {
    _multiplyResult = a * b;
  }

  function getMultiplyResult() public view returns (uint256) {
    return _addResult;
  }

  function getAddResult() public view returns (uint256) {
    return _multiplyResult;
  }
}

//An investor schedule contract maintains the token vesting schedules such that the tokens are emitted over time and not immediately. Typically, the tokens are locked until a certain time passes upon which the tokens are unlocked and can be withdrawn. So let's make one 🙂

//4. Finally, we want a function that allows us to withdraw our tokens and set our balance to however much we withdraw.

//As always, if you need help, feel free to ask!
import "@openzeppelin/contracts/interfaces/IERC20.sol";
error InvestorSchedule__DoesNotHaveEnoughERC20();
error InvestorSchedule__DoesNotHaveAllowanceERC20();
error InvestorSchedule__IERC20TransferFailed();
error InvestorSchedule__EndlockAlreadyPassed();
error InvestorSchedule__WithdrawTooMuch();

contract InvestorSchedule {
  //1. We would need a struct that holds the balance, address, and lock time of each person that has a vesting schedule. This will be our ledger for holding account statuses.
  struct Investoor {
    uint256 balance;
    IERC20 token;
    uint256 startlock;
    uint256 endlock;
  }
  // this only supports one investment
  mapping(address => Investoor) addressToInvestoor;

  event InvestoorCreated(uint256 balance, address erc20, uint256 startlock, uint256 endlock);
  event InvestoorDeleted(uint256 balance, address erc20, uint256 endlock);
  event InvestoorUpdated(uint256 balance, address erc20, uint256 startlock, uint256 endlock);

  constructor() {}

  function getInvestoor(address account)
    public
    view
    returns (
      uint256 balance,
      address token,
      uint256 startlock,
      uint256 endlock
    )
  {
    Investoor memory investor = addressToInvestoor[account];
    return (investor.balance, address(investor.token), investor.startlock, investor.endlock);
  }

  //2. We would need a function that lets us create an account with balance, address, and set the lock time as the time when we call the contract (block.timestamp).
  function createAccount(
    address erc20,
    uint256 amount,
    uint256 endlock
  ) public {
    if (amount < 0) {
      revert InvestorSchedule__DoesNotHaveEnoughERC20();
    }
    if (block.timestamp > endlock) {
      revert InvestorSchedule__EndlockAlreadyPassed();
    }
    // add getBalance check
    uint256 allowance = IERC20(erc20).allowance(msg.sender, address(this));
    if (allowance < amount) {
      revert InvestorSchedule__DoesNotHaveAllowanceERC20();
    }
    // RUG
    bool res = IERC20(erc20).transferFrom(msg.sender, address(this), amount);

    if (!res) {
      revert InvestorSchedule__IERC20TransferFailed();
    }

    addressToInvestoor[msg.sender] = Investoor({
      balance: amount,
      token: IERC20(erc20),
      startlock: block.timestamp,
      endlock: endlock
    });
    emit InvestoorCreated(amount, erc20, block.timestamp, endlock);
  }

  //3. Then, we would need a function that calculates a withdraw allowance schedule so that at the start of the lock, balance locked will be the total initial, and that whenever a certain time passes, tokens will be linearly released for the time period.
  //ex. At block 0, I have 100 locked tokens I cannot withdraw. At block 50, I have 50 locked tokens, but my withdraw balance is 50 tokens released. And at block 100, all my tokens are released.
  function withdrawable(address account) public view returns (uint256) {
    // TODO: I believe that it is okay if this is not storage, but memory or calldata?
    Investoor memory investor = addressToInvestoor[account];

    // praying this reverts if investor does not exist
    if (investor.endlock < block.timestamp) {
      return investor.balance;
    }
    // withdrawable = -tokenAmount  * block.timestamp/ (endlock - startlock) + tokenAmount
    return
      (((investor.balance * (investor.endlock - investor.startlock)) -
        investor.balance *
        block.timestamp) * 1e18) / (investor.endlock - investor.startlock);
  }

  //4. Finally, we want a function that allows us to withdraw our tokens and set our balance to however much we withdraw.
  function withdraw(uint256 amount) public {
    uint256 withdrawableAmount = withdrawable(msg.sender) / 1e18;
    if (withdrawableAmount < amount) {
      revert InvestorSchedule__WithdrawTooMuch();
    }

    //I believe this needs to be storage because we are going to be editting the object
    Investoor storage investor = addressToInvestoor[msg.sender];
    uint256 newBalance = investor.balance - amount;
    if (newBalance == 0) {
      // why can't I use investor here
      delete addressToInvestoor[msg.sender];
      emit InvestoorDeleted(newBalance, address(investor.token), block.timestamp);

      return;
    }

    investor.balance = newBalance;
    investor.startlock = block.timestamp;
    emit InvestoorUpdated(
      newBalance,
      address(investor.token),
      investor.startlock,
      investor.endlock
    );
  }
}

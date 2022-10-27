// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.7;
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// interface SmartWalletChecker {
//   function check(address addr) returns (bool);
// }

// contract VotingEscrow {
//   struct Point {
//     int128 bias;
//     int128 slope;
//     uint256 ts;
//     uint256 blk;
//   }
//   struct LockedBalance {
//     int128 amount;
//     uint256 end;
//   }
//   enum Action {
//     DEPOSIT_FOR_TYPE,
//     CREATE_LOCK_TYPE,
//     INCREASE_LOCK_AMOUNT,
//     INCREASE_UNLOCK_TIME
//   }
//   event CommitOwnership(address admin);
//   event ApplyOwnership(address admin);
//   event Deposit(address indexed provider, uint256 value, uint256 indexed locktime);
//   event Withdraw(address indexed provider, uint256 value, uint256 ts);
//   event Supply(uint256 prevSupply, uint256 supply);
//   uint256 constant WEEK = 7 * 86400;
//   uint256 constant MAXTIME = 4 * 365 * 86400;
//   uint256 constant MULTIPLIER = 10**18;

//   address public token;
//   address public supply;
//   mapping(address => LockedBalance) public locked;
//   uint256 public epoch;
//   Point[100000000000000000000000000000] public point_history;
//   mapping(address => Point[1000000000]) public user_point_history;
//   mapping(address => uint256) public user_point_epoch;
//   mapping(uint256 => int128) public slope_changes;

//   // Aragon's view methods for compatibility
//   address public controller;
//   bool public transfersEnabled;

//   string[64] public name; //TODO: is this an array or 64 length string?
//   string[32] public symbol; //TODO: is this an array or 32 length string?
//   uint256 public decimals;

//   address public future_smart_wallet_checker;
//   address public smart_wallet_checker;
//   address public admin;
//   address public future_admin;

//   modifier onlyAdmin() {
//     require(msg.sender == admin, "admin only");
//     _;
//   }

//   constructor(
//     address token_addr,
//     string _name,
//     string _symbol,
//     string _version
//   ) {
//     admin = msg.sender;
//     token = token_addr;
//     point_history[0].blk = block.number;
//     point_history[0].ts = block.timestamp;
//     controller = msg.sender;
//     transfersEnabled = true;
//     uint256 _decimals = IERC20(token_addr).decimals();
//     require(_decimals <= 255);
//     decimals = _decimals;
//     name = _name;
//     symbol = _symbol;
//     version = _version;
//   }

//   /**
//    * @notice Transfer ownership of VotingEscrow contract to `addr`
//    * @param addr Address to have ownership transferred to
//    */
//   function commit_transfer_ownership(address addr) external onlyAdmin {
//     future_admin = addr;
//     emit CommitOwnership(addr);
//   }

//   /**
//    * @notice Apply ownership transfer
//    */
//   function apply_transfer_ownership() external onlyAdmin {
//     address _admin = future_admin;
//     require(_admin != address(0), "admin not set");
//     admin = _admin;
//     emit ApplyOwnership(_admin);
//   }

//   /**
//    * @notice Set an external contract to check for approved smart contract wallets
//    * @param addr Address of Smart contract checker
//    */
//   function commit_smart_wallet_checker(address addr) external onlyAdmin {
//     future_smart_wallet_checker = addr;
//   }

//   /**
//    * @notice Apply setting external contract to check approved smart contract wallets
//    */
//   function apply_smart_wallet_checker() external onlyAdmin {
//     smart_wallet_checker = future_smart_wallet_checker;
//   }

//   /**
//    * @notice Check if the call is from a whitelisted smart contract, revert if not
//    * @param addr Address to be checked
//    */
//   function assert_not_contract(address addr) internal {
//     if (addr != tx.origin) {
//       address checker = smart_wallet_checker;
//       if (checker != address(0)) {
//         if (SmartWalletChecker(checker).check(addr)) {
//           return;
//         }
//       }
//       require(true, "Smart contract depositors not allowed");
//     }
//   }

//   /**
//    * @notice Get the most recently recorded rate of voting power decrease for `addr`
//    * @param addr Address of the user wallet
//    * @return Value of the slope
//    */
//   function get_last_user_slope(address addr) external view returns (int128) {
//     uint256 uepoch = user_point_epoch[addr];
//     return user_point_history[addr][uepoch].slope;
//   }

//   /**
//    * @notice Get the timestamp for checkpoint `_idx` for `_addr`
//    * @param _addr User wallet address
//    * @param _idx User epoch number
//    * @return Epoch time of the checkpoint
//    */
//   function user_point_history__ts(address _addr, uint256 _idx) external view returns (uint256) {
//     return user_point_history[_addr][_idx].ts;
//   }

//   /**
//    * @notice Get timestamp when `_addr`'s lock finishes
//    * @param _addr User wallet
//    * @return Epoch time of the lock end
//    */
//   function locked__end(address _addr) external view returns (uint256) {
//     return locked[_addr].end;
//   }

//   /**
//    * @notice Record global and per-user data to checkpoint
//    * @param addr User's wallet address. No user checkpoint if 0x0
//    * @param old_locked Previous locked amount / end lock time for the user
//    * @param new_locked New locked amount / end lock time for the user
//    */
//   function _checkpoint(
//     address addr,
//     LockedBalance old_locked,
//     LockedBalance new_locked
//   ) {
//     Point memory u_old;
//     Point memory u_new;
//     int128 old_dslope = 0;
//     int128 new_dslope = 0;
//     uint256 _epoch = epoch;
//     if (addr != address(0)) {
//       if (old_locked.end > block.timestamp && old_locked.amount > 0) {
//         u_old.slope = old_locked.amount / MAXTIME;
//         u_old.bias = u_old.slope * uint128(old_locked.end - block.timestamp);
//       }
//       if (new_locked.end > block.timestamp && new_locked.amount > 0) {
//         u_new.slope = new_locked.amount / MAXTIME;
//         u_new.bias = u_new.slope * uint128(new_locked.end - block.timestamp);
//       }
//       old_dslope = slope_changes[old_locked.end];
//       if (new_locked.end != 0) {
//         if (new_locked.end == old_locked.end) {
//           new_dslope = old_dslope;
//         } else {
//           new_dslope = slope_changes[new_locked.end];
//         }
//       }
//     }
//     Point last_point = Point({bias: 0, slope: 0, ts: block.timestamp, blk: block.number});
//     if (_epoch > 0) {
//       last_point = point_history[_epoch];
//     }
//     uint256 last_checkpoint = last_point.ts;
//     Point initial_last_point = last_point;
//     uint256 block_slope = 0; //dblock/dt
//     if (block.timestamp > last_point.ts) {
//       block_slope =
//         (MULTIPLIER * (block.number - last_point.blk)) /
//         (block.timestamp - last_point.ts);
//     }
//     uint256 t_i = (last_checkpoint / WEEK) * WEEK;
//     for (uint8 i = 0; i < 256; i++) {
//       // TODO: confirm range(255) in vyper is equal
//       // Hopefully it won't happen that this won't get used in 5 years! //TODO what does this mean?
//       // If it does, users will be able to withdraw but vote weight will be broken
//       t_i += WEEK;
//       uint128 d_slope = 0;
//       if (t_i > block.timestamp) {
//         t_i = block.timestamp;
//       } else {
//         d_slope = slope_changes[t_i];
//       }
//       last_point.bias -= last_point.slope * int128(t_i - last_checkpoint);
//       last_point.slope += d_slope;
//       if (last_point.bias < 0) {
//         last_point.bias = 0;
//       }
//       if (last_point.slope < 0) {
//         last_point.slope = 0;
//       }
//       last_checkpoint = t_i;
//       last_point.ts = t_i;
//       last_point.blk =
//         initial_last_point.blk +
//         (block_slope * (t_i - initial_last_point.ts)) /
//         MULTIPLIER;
//       _epoch += 1;
//       if (t_i == block.timestamp) {
//         last_point.blk = block.number;
//         break;
//       } else {
//         self.point_history[_epoch] = last_point;
//       }
//     }
//     epoch = _epoch;
//     // Now point_history is filled until t=now

//     if (addr != address(0)) {
//       // If last point was in this block, the slope change has been applied already
//       // But in such case we have 0 slope(s)
//       last_point.slope += (u_new.slope - u_old.slope);
//       last_point.bias += (u_new.bias - u_old.bias);
//       if (last_point.slope < 0) {
//         last_point.slope = 0;
//       }
//       if (last_point.bias < 0) {
//         last_point.bias = 0;
//       }
//     }
//     // Record the changed point into history
//     self.point_history[_epoch] = last_point;

//     if (addr != address(0)) {
//       // Schedule the slope changes (slope is going down)
//       // We subtract new_user_slope from [new_locked.end]
//       // and add old_user_slope to [old_locked.end]
//       if (old_locked.end > block.timestamp) {
//         // old_dslope was <something> - u_old.slope, so we cancel that
//         old_dslope += u_old.slope;
//         if (new_locked.end == old_locked.end) {
//           old_dslope -= u_new.slope; // It was a new deposit, not extension
//         }
//         slope_changes[old_locked.end] = old_dslope;
//       }
//       if (new_locked.end > block.timestamp) {
//         if (new_locked.end > old_locked.end) {
//           new_dslope -= u_new.slope; // old slope disappeared at this point
//           self.slope_changes[new_locked.end] = new_dslope;
//         }
//         // else: we recorded it already in old_dslope
//       }
//       // Now handle user history
//       uint256 user_epoch = self.user_point_epoch[addr] + 1;

//       self.user_point_epoch[addr] = user_epoch;
//       u_new.ts = block.timestamp;
//       u_new.blk = block.number;
//       self.user_point_history[addr][user_epoch] = u_new;
//     }
//   }
// }

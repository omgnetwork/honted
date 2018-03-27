//   Copyright 2018 OmiseGO Pte Ltd
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

pragma solidity 0.4.19;

import './token/ERC20.sol';
import './math/SafeMath.sol';

contract HonteStaking {
  using SafeMath for uint256;

  /*
   *  Events
   */

  event Deposit(address indexed depositor, uint256 amount);
  event Join(address indexed joiner, uint256 indexed epoch, uint256 amount);
  event Eject(address indexed ejected, uint256 ejectingAmount);
  event Withdraw(address indexed withdrawer, uint256 amount);

  /*
   *  Storage
   */

  struct validator {
    uint256 stake;
    bytes32 tendermintPubkey;
    address owner;
    bool isContinuing;
  }

  // a double mapping staker_address => epoch_number => amount deposited/withdrawable in epoch_number for staker
  mapping (address => mapping(uint256 => uint256)) public deposits;
  mapping (uint256 => mapping(uint256 => validator)) private validatorSets;

  ERC20   token;

  uint256 public epochLength;
  uint256 public maturityMargin;
  uint256 public maxNumberOfValidators;

  uint256 public startBlock;
  uint256 public unbondingPeriod;

  // imposed to steer cleer of validators overloading tendermint or too gas-costly joins
  uint256 constant safetyLimitForValidators = 100;

  /*
   *  Public functions
   */

  /** @dev Instantiates a staking contract. Sets starting block of first epoch to current block number
   * @param _epochLength length of a single epoch in blocks
   * @param _maturityMargin length of the maturity margin in blocks - period when one can't join the next epoch anymore
   * @param _tokenAddress address of the staking token
   * @param _maxNumberOfValidators maximum number of validators allowed, i.e. only top stakers become validators
   */
  function HonteStaking(uint256 _epochLength,
                        uint256 _maturityMargin,
                        address _tokenAddress,
                        uint256 _maxNumberOfValidators)
    public
  {
    // safety checks
    require(_maxNumberOfValidators > 0);
    require(_maxNumberOfValidators <= safetyLimitForValidators);
    require(_epochLength > _maturityMargin);
    require(_maturityMargin > 0);
    require(_tokenAddress != 0x0);

    startBlock            = block.number;
    token                 = ERC20(_tokenAddress);
    epochLength           = _epochLength;
    unbondingPeriod       = 1;
    maturityMargin        = _maturityMargin;
    maxNumberOfValidators = _maxNumberOfValidators;
  }

  /** @dev Will place a (withdrawable until join) deposit. Withdraw this using a `withdraw(0)` transaction
    * @param amount amount to deposit in smallest token's denomination
    */
  function deposit(uint256 amount)
    public
  {
    require(amount <= token.allowance(msg.sender, address(this)));

    token.transferFrom(msg.sender, address(this), amount);
    registerNewDeposit(amount);

    Deposit(msg.sender, amount);
  }

  /** @dev Will attempt to join the next epoch for validation using fresh deposit and current stake (if available)
    * @param tendermintPubkey the public address of the tendermint validator and receiver of fees earned
    *                          NOTE: this assumes tendermint/crypto's EC type 0x01 is used
    */
  function join(bytes32 tendermintPubkey)
    public
  {
    // Checks to make sure the tendermint address isn't null which could be an easy error
    //
    require(tendermintPubkey != 0x0);

    uint256 currentEpoch         = getCurrentEpoch();
    uint256 nextEpoch            = currentEpoch.add(1);
    uint256 unbondingEpoch       = nextEpoch.add(1).add(unbondingPeriod);

    // Checks to make sure that the next epochs validators set isn't locked yet
    //
    require(notInMaturityMargin());

    uint256 newValidatorPosition  = getNewValidatorPosition(nextEpoch);
    // Sanity checks if an impossible condition doesn't happen (overflowing the allowed size of validators)
    assert(newValidatorPosition < maxNumberOfValidators);

    // Creates/updates new validator from a joiner
    //
    if (validatorSets[nextEpoch][newValidatorPosition].owner == msg.sender) {
      // this isn't ejecting - joiner is already present in the next epoch's validator set
      // we just update the stake
      validatorSets[nextEpoch][newValidatorPosition].stake = validatorSets[nextEpoch][newValidatorPosition].stake.add(deposits[msg.sender][0]);
    } else {
      // ejecting (possibly an empty slot)

      // ejecting validator has already staked this much...
      uint256 currentStake = currentStakeOfJoiner(currentEpoch);
      // ejected validator will be...
      validator storage modifiedValidatorEntry = validatorSets[nextEpoch][newValidatorPosition];
      // do it!
      ejectAndJoin(modifiedValidatorEntry, currentStake, unbondingEpoch);
    }

    // want to give the possibility of updating the tendermint address regardless
    validatorSets[nextEpoch][newValidatorPosition].tendermintPubkey = tendermintPubkey;

    // Creates/updates withdraw - combines the fresh deposit with the currently validating stake
    //
    moveDeposit(msg.sender, 0, unbondingEpoch);
    moveDeposit(msg.sender, unbondingEpoch - 1, unbondingEpoch);

    Join(msg.sender, nextEpoch, validatorSets[nextEpoch][newValidatorPosition].stake);
  }

  /** @dev Withdraws the deposit withdrawable after a certain epoch, i.e. withdraws from a certain "withdraw slot"
    * @param epoch the epoch where one expects a withdrawable deposit to be present for withdrawal
    */
  function withdraw(uint256 epoch)
    public
  {
    require(hasStarted(epoch));

    uint256 amount = deposits[msg.sender][epoch];

    require(amount != 0);

    delete deposits[msg.sender][epoch];
    token.transfer(msg.sender, amount);

    Withdraw(msg.sender, amount);
  }

  /*
   *  Constant functions
   */

   /** @dev Manual override of default `validatorSets` getter to hide private field isContinuing
     * @param epoch the validating epoch queried
     * @param validatorIdx the index of the queried validator slot (must be in 0:maxNumberOfValidators)
     * @return stake returned validator's stake in smallest token denomination
     * @return tendermintPubkey the validators public address of the tendermint validator
     * @return owner the validators address on ethereum, 0x0 if the slot is empty
     */
   function getValidator(uint256 epoch, uint256 validatorIdx)
     public
     view
     returns (uint256 stake, bytes32 tendermintPubkey, address owner)
   {
     validator memory queriedValidator = validatorSets[epoch][validatorIdx];

     stake = queriedValidator.stake;
     tendermintPubkey = queriedValidator.tendermintPubkey;
     owner = queriedValidator.owner;
   }

  /** @dev Gets current epoch based on current mined block number and parameters of the staking contract
    * @return 0-based Index of the current epoch
    */
  function getCurrentEpoch()
    public
    view
    returns(uint256)
  {
    uint256 blocksSinceStart = block.number.sub(startBlock);
    return blocksSinceStart.div(epochLength);
  }

  /** @dev Gets the block number where the next epoch starts, respective to the currently mined block height
    * @return first block of the next epoch
    */
  function getNextEpochBlockNumber()
    public
    view
    returns(uint256)
  {
    uint256 nextEpoch      = getCurrentEpoch().add(1);
    return startBlock.add(nextEpoch.mul(epochLength));
  }

  /*
   *  Private functions
   */

  function hasStarted(uint256 epoch)
    private
    view
    returns (bool)
  {
    return epoch <= getCurrentEpoch();
  }

  function getNewValidatorPosition(uint256 epoch)
    private
    view
    returns (uint256)
  {
    uint256 lowestValidatorAmount   = 2**255;
    uint256 lowestValidatorPosition = 0;

    for(uint256 i = 0; i < maxNumberOfValidators; i++) {
      // If a validator spot is empty exit the loop and join at that position or
      // if the joiner is already an existing validator in the set
      //
      if (validatorSets[epoch][i].owner == 0x0 || validatorSets[epoch][i].owner == msg.sender) {
        return i;
      }

      // Tracks the minimum stake and save its position
      //
      else if (validatorSets[epoch][i].stake < lowestValidatorAmount) {
        lowestValidatorPosition = i;
        lowestValidatorAmount = validatorSets[epoch][lowestValidatorPosition].stake;
      }
    }

    return lowestValidatorPosition;
  }

  function registerNewDeposit(uint256 amount)
    private
  {
    deposits[msg.sender][0] = deposits[msg.sender][0].add(amount);
  }

  function notInMaturityMargin()
    private
    view
    returns (bool)
  {
    uint256 nextEpochBlockNumber = getNextEpochBlockNumber();
    return block.number < nextEpochBlockNumber.sub(maturityMargin);
  }

  function currentStakeOfJoiner(uint256 currentEpoch)
    private
    view
    returns (uint256 alreadyStaked)
  {
    alreadyStaked = 0;
    for (uint256 i = 0; i < maxNumberOfValidators; i++) {
      if (validatorSets[currentEpoch][i].owner == msg.sender) {
        alreadyStaked = validatorSets[currentEpoch][i].stake;
        break;
      }
    }
  }

  function ejectAndJoin(validator storage modifiedValidatorEntry,
                        uint256 currentStake,
                        uint256 unbondingEpoch)
    private
  {
    // If there has already been a stake for the joiner, it is a continuing join
    bool joinerIsContinuing = currentStake > 0;

    uint256 sumToStake = deposits[msg.sender][0].add(currentStake);
    address ejectedValidator = modifiedValidatorEntry.owner;
    uint256 ejectedValidatorAmount = modifiedValidatorEntry.stake;
    bool ejectedValidatorWasContinuing = modifiedValidatorEntry.isContinuing;

    // Checks that the joiners stake is higher than the lowest current validators deposit
    //
    require(ejectedValidatorAmount < sumToStake);

    // Ejects and overwrites (possibly an empty slot)
    modifiedValidatorEntry.owner = msg.sender;
    modifiedValidatorEntry.stake = sumToStake;
    modifiedValidatorEntry.isContinuing = joinerIsContinuing;

    if (ejectedValidator != 0x0) {
      // fire alert that someone got ejected
      Eject(ejectedValidator, sumToStake);

      // Free ejected validators deposit
      if (ejectedValidatorWasContinuing) {
        moveDeposit(ejectedValidator, unbondingEpoch, unbondingEpoch - 1);
      } else {
        moveDeposit(ejectedValidator, unbondingEpoch, 0);
      }
    }
  }

  function moveDeposit(address owner, uint256 fromEpoch, uint256 toEpoch)
    private
  {
    assert(fromEpoch != toEpoch); // futureproofing: would fail and is currently impossible
    uint256 movedAmount = deposits[owner][fromEpoch];
    // `if` to prevent an expensive no-op
    if (movedAmount > 0) {
      deposits[owner][toEpoch]   = deposits[owner][toEpoch].add(movedAmount);
      deposits[owner][fromEpoch] = 0;
    }
  }

}

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
  event Withdraw(address indexed withdrawer, uint256 amount);

  /*
   *  Storage
   */

  struct validator {
    uint256 stake;
    address tendermintAddress;
    address owner;
  }

  // a double mapping staker_address => epoch_number => amount deposited/withdrawable in epoch_number
  mapping (address => mapping(uint256 => uint256)) public deposits;
  mapping (uint256 => mapping(uint256 => validator)) public validatorSets;

  uint256 public startBlock;
  ERC20   token;
  uint256 public epochLength;
  uint256 public unbondingPeriod;
  uint256 public maturityMargin;
  uint256 public maxNumberOfValidators;
  uint256 lastLowestDeposit;

  /*
   *  Public functions
   */

  function HonteStaking(uint256 _epochLength, uint256 _maturityMargin, address _tokenAddress, uint256 _maxNumberOfValidators)
    public
  {
    startBlock            = block.number;
    token                 = ERC20(_tokenAddress);
    epochLength           = _epochLength;
    unbondingPeriod       = 1;
    maturityMargin        = _maturityMargin;
    maxNumberOfValidators = _maxNumberOfValidators;
  }

  function deposit(uint256 amount)
    public
  {
    require(amount <= token.allowance(msg.sender, address(this)));

    // FIXME: not worth it? besides you should include the current validating stake here as well...
    // commented because it's hard to fix and probably will be removed
    /* require(deposits[msg.sender].add(amount) > lastLowestDeposit); */

    token.transferFrom(msg.sender, address(this), amount);
    deposits[msg.sender][0] = deposits[msg.sender][0].add(amount);

    Deposit(msg.sender, amount);
  }

  function join(address _tendermintAddress)
    public
  {
    // Checks to make sure the tendermint address isn't null
    //
    require(_tendermintAddress != 0x0);

    uint256 currentEpoch         = getCurrentEpoch();
    uint256 nextEpoch            = currentEpoch.add(1);
    uint256 nextEpochBlockNumber = getNextEpochBlockNumber();

    // Checks to make sure that the next epochs validators set isn't locked yet
    //
    require(block.number < nextEpochBlockNumber.sub(maturityMargin));

    uint256 newValidatorPosition  = getNewValidatorPosition(nextEpoch);
    uint256 ejectedValidtorAmount = validatorSets[nextEpoch][newValidatorPosition].stake;

    // Checks that the joiners stake is higher than the lowest current validators deposit
    //
    // FIXME: will throw if msg.sender is continueing
    require(ejectedValidtorAmount < deposits[msg.sender][0]);

    // Creates/updates new validator from a joiner
    //
    if (validatorSets[nextEpoch][newValidatorPosition].owner == msg.sender) {
      validatorSets[nextEpoch][newValidatorPosition].stake = validatorSets[currentEpoch][newValidatorPosition].stake.add(deposits[msg.sender][0]);
    } else {
      validatorSets[nextEpoch][newValidatorPosition].owner = msg.sender;
      validatorSets[nextEpoch][newValidatorPosition].stake = deposits[msg.sender][0];
      // FIXME: handle withdrawal for the ejectee (either continuing or not)
      // FIXME: consider changing withdrawable_at to subaccounts for epochs
    }
    validatorSets[nextEpoch][newValidatorPosition].tendermintAddress = _tendermintAddress;

    // Creates/updates withdraw
    //
    moveDeposit(msg.sender, 0, nextEpoch.add(1).add(unbondingPeriod));

    Join(msg.sender, nextEpoch, validatorSets[nextEpoch][newValidatorPosition].stake);
  }

  function moveDeposit(address owner, uint256 fromEpoch, uint256 toEpoch)
    private
  {
     deposits[owner][toEpoch]   = deposits[owner][toEpoch].add(deposits[owner][fromEpoch]);
     deposits[owner][fromEpoch] = 0;
  }

  function withdraw(uint256 epoch)
    public
  {
    require(epoch <= getCurrentEpoch());

    uint256 amount = deposits[msg.sender][epoch];

    require(amount != 0);

    delete deposits[msg.sender][epoch];
    token.transfer(msg.sender, amount);

    Withdraw(msg.sender, amount);
  }

  /*
   *  Constant functions
   */

  function getCurrentEpoch()
    public
    view
    returns(uint256)
  {
    uint256 blocksSinceStart = block.number.sub(startBlock);
    return blocksSinceStart.div(epochLength);
  }

  function getNextEpochBlockNumber()
    public
    view
    returns(uint256)
  {
    uint256 nextEpoch      = getCurrentEpoch().add(1);
    uint256 nextEpochBlock = startBlock.add(nextEpoch.mul(epochLength));
    return nextEpochBlock;
  }

  /*
   *  Private functions
   */

  function getNewValidatorPosition(uint256 epoch)
    public
    view
    returns(uint256)
  {
    uint256 lowestValidatorAmount   = 2**255;
    uint256 lowestValidatorPosition = 0;

    for(uint256 i = 0; i < maxNumberOfValidators; i++) {
      // If a validator spot is empty exit the loop and join at that position or
      // if the joiner is already an existing validator in the set
      //
      if (validatorSets[epoch][i].owner == 0x0 || validatorSets[epoch][i].owner == msg.sender) {
        // FIXME: careful, can self-eject now if I overwrite my own stake
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
}

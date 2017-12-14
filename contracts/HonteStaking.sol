pragma solidity 0.4.19;

import './token/ERC20.sol';
import './math/SafeMath.sol';

contract HonteStaking {
  using SafeMath for uint256;

  /*
   *  Events
   */

  event Deposit(address indexed depositor, uint256 amount);
  event Join(address indexed joiner, uint256 amount);
  event Withdraw(address indexed withdrawer, uint256 amount);

  /*
   *  Storage
   */

  struct validator {
    uint256 stake;
    address tendermintAddress;
    address owner;
  }

  struct withdrawal {
    uint256 amount;
    uint256 withdrawableAt;
  }

  mapping (address => uint256) public deposits;
  mapping (uint256 => mapping(uint256 => validator)) public validatorSets;
  mapping (address => withdrawal) withdrawals;

  uint256 startBlock;
  ERC20   token;
  uint256 epochLength;
  uint256 maturityMargin;
  uint256 maxNumberOfValidators;
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
    maturityMargin        = _maturityMargin;
    maxNumberOfValidators = _maxNumberOfValidators;
  }

  function deposit(uint256 amount)
    public
  {
    require(amount <= token.allowance(msg.sender, address(this)));
    
    // FIXME: not worth it? besides you should include the current validating stake here as well...
    require(deposits[msg.sender].add(amount) > lastLowestDeposit);

    token.transferFrom(msg.sender, address(this), amount);
    deposits[msg.sender] = deposits[msg.sender].add(amount);

    Deposit(msg.sender, amount);
  }

  function deposited(address owner)
      view public returns (uint256) {
      return deposits[owner];
  }

  function join(address _tendermintAddress)
    public
  {
    // Checks to make sure the tendermint address isn't null
    //
    require(_tendermintAddress != 0x0);

    uint256 currentEpoch         = getCurrentEpoch();
    uint256 nextEpochBlockNumber = getNextEpochBlockNumber();

    // Checks to make sure that the next epochs validators set isn't locked yet
    //
    require(block.number < nextEpochBlockNumber.sub(maturityMargin));

    uint256 lowestValidatorPosition = getNewValidatorPosition(currentEpoch);

    // Creates/updates new validator from a joiner
    //
    if (validatorSets[currentEpoch][lowestValidatorPosition].owner == msg.sender) {
      validatorSets[currentEpoch][lowestValidatorPosition].stake = validatorSets[currentEpoch][lowestValidatorPosition].stake.add(deposits[msg.sender]);
    } else {
      validatorSets[currentEpoch][lowestValidatorPosition].owner = msg.sender;
      validatorSets[currentEpoch][lowestValidatorPosition].stake = deposits[msg.sender];
      // FIXME: handle withdrawal for the ejectee (either continuing or not)
      // FIXME: consider changing withdrawable_at to subaccounts for epochs
    }
    validatorSets[currentEpoch][lowestValidatorPosition].tendermintAddress = _tendermintAddress;

    // Creates/updates withdraw
    //
    withdrawals[msg.sender].amount         = withdrawals[msg.sender].amount.add(deposits[msg.sender]);
    withdrawals[msg.sender].withdrawableAt = nextEpochBlockNumber.add(epochLength);

    // Delete the deposit
    //
    delete deposits[msg.sender];

    Join(msg.sender, withdrawals[msg.sender].amount);
  }

  function withdraw()
    public
  {
    require(withdrawals[msg.sender].withdrawableAt <= block.number);

    token.transfer(msg.sender, withdrawals[msg.sender].amount);
    delete withdrawals[msg.sender];

    Withdraw(msg.sender, withdrawals[msg.sender].amount);
  }

  /*
   *  Constant functions
   */

  function getCurrentEpoch()
    public
    view
    returns(uint256)
  {
    return block.number.sub(startBlock).div(epochLength);
  }

  function getNextEpochBlockNumber()
    public
    view
    returns(uint256)
  {
    // uint256 currentEpoch   = block.number.sub(startBlock).div(epochLength);
    // uint256 nextEpoch      = currentEpoch.add(1);
    // uint256 nextEpochBlock = startblock.add(nextEpoch.mul(epochLength));
    return startBlock.add((block.number.sub(startBlock).div(epochLength).add(1)).mul(epochLength));
  }

  /*
   *  Private functions
   */

  function getNewValidatorPosition(uint256 currentEpoch)
    private
    view
    returns(uint256)
  {
    uint256 lowestValidatorAmount   = 2**255;
    uint256 lowestValidatorPosition = 0;

    for(uint256 i = 0; i < maxNumberOfValidators; i++) {
      lowestValidatorPosition = i;

      // If a validator spot is empty exit the loop and join at that position or
      // if the joiner is already an existing validator in the set
      //
      if (validatorSets[currentEpoch][i].owner == 0x0 || validatorSets[currentEpoch][i].owner == msg.sender) {
        break;
      }

      // Tracks the minimum stake and save its position
      //
      else if (validatorSets[currentEpoch][i].stake < lowestValidatorAmount) {
        lowestValidatorAmount = validatorSets[currentEpoch][i].stake;
      }
    }

    // Checks that the joiners stake is higher than the lowest current validators deposit
    //
    // FIXME: will throw if msg.sender is continueing
    // FIXME: even so, this shouldn't be here, but outside
    require(lowestValidatorAmount < deposits[msg.sender]);

    return lowestValidatorPosition;
  }
}

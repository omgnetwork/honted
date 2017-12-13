pragma solidity 0.4.19;
import './token/ERC20.sol';
import './math/SafeMath.sol';

contract HonteStaking {
  using SafeMath for uint256;

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
  mapping (uint256 => validator[]) public validatorSets;
  mapping (address => withdrawal) withdrawals;
  uint256 startBlock;
  ERC20 token;
  uint256 epochLength;
  uint256 maturityMargin;
  uint256 maxNumberOfValidators;

  /*
   *  Public functions
   */
  function HonteStaking(uint256 _epochLength, uint256 _maturityMargin, address _tokenAddress, uint256 _maxNumberOfValidators)
    public
  {
    startBlock = block.number;
    token = ERC20(_tokenAddress);
    epochLength = _epochLength;
    maturityMargin = _maturityMargin;
    maxNumberOfValidators = _maxNumberOfValidators;
  }

  function deposit(uint256 amount)
    public
  {
    /* TODO guard against depositing an amount lower than the lowest validator */
    require(amount <= token.allowance(msg.sender, address(this)));
    token.transferFrom(msg.sender, address(this), amount);
    deposits[msg.sender] = deposits[msg.sender].add(amount);
    /* TODO add log */
  }

  function join(address _tendermintAddress)
    public
  {
    // Checks to make sure the tendermint address isn't null
    require(_tendermintAddress != 0x0);
    uint256 currentEpoch = getCurrentEpoch();
    uint256 nextEpochBlockNumber = getNextEpochBlockNumber();
    // Checks to make sure that the next epochs validators set isn't locked yet
    require(block.number < nextEpochBlockNumber.sub(maturityMargin));
    uint256 lowestValidatorAmount = 2**255;
    uint256 lowestValidatorPosition = 0;
    for(uint256 i = 0; i < maxNumberOfValidators; i++) {
      // If a validator spot is empty exit the loop and join at that position or
      // if the joiner is already an existing validator in the set
      if (validatorSets[currentEpoch][i].owner == 0x0 || validatorSets[currentEpoch][i].owner == msg.sender) {
        lowestValidatorPosition = i;
        break;
      }
      // Tracks the minimum stake and save its position
      else if (validatorSets[currentEpoch][i].stake < lowestValidatorAmount) {
        lowestValidatorPosition = i;
        lowestValidatorAmount = validatorSets[currentEpoch][i].stake;
      }
    }
    // Checks that the joiners stake is higher than the lowest current validators deposit
    require(lowestValidatorAmount < deposits[msg.sender]);
    // Creates the new validator from a joiner
    validatorSets[currentEpoch][lowestValidatorPosition].stake = validatorSets[currentEpoch][lowestValidatorPosition].stake.add(deposits[msg.sender]);
    validatorSets[currentEpoch][lowestValidatorPosition].tendermintAddress = _tendermintAddress;
    validatorSets[currentEpoch][lowestValidatorPosition].owner = msg.sender;
    withdrawals[msg.sender].amount = deposits[msg.sender];
    withdrawals[msg.sender].withdrawableAt = nextEpochBlockNumber.add(epochLength);
    // Delete the deposit
    delete deposits[msg.sender];
  }

  function withdraw()
    public
  {
    require(withdrawals[msg.sender].withdrawableAt <= block.number);
    token.transfer(msg.sender, withdrawals[msg.sender].amount);
  }

  /*
   * Constant functions
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
    // uint256 currentEpoch = block.number.sub(startBlock).div(epochLength);
    // uint256 nextEpoch = currentEpoch.add(1);
    // uint256 nextEpochBlock = startblock.add(nextEpoch.mul(epochLength));
    return startBlock.add((block.number.sub(startBlock).div(epochLength).add(1)).mul(epochLength));
  }

  //function

}

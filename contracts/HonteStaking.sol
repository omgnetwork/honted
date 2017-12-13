pragma solidity 0.4.19;
import './token/ERC20.sol';
import './math/SafeMath.sol';

contract HonteStaking {
  using SafeMath for uint256;

  /*
   *  Constants
   */
  uint256 public constant EPOCH_LENGTH = 172800;
  address public constant OMG_TOKEN_ADDRESS = 0xd26114cd6EE289AccF82350c8d8487fedB8A0C07;

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
  mapping (uint256 => validator[100]) public validatorSets;
  mapping (address => withdrawal) withdrawals;
  uint256 startBlock;
  ERC20 token;

  /*
   *  Public functions
   */
  function HonteStaking()
    public
  {
    startBlock = block.number;
    token = ERC20(OMG_TOKEN_ADDRESS);
  }

  function deposit(uint256 amount)
    public
  {
    require(token.allowance(msg.sender, address(this)) == amount);
  }

  function join(address _tendermindAddress){}

  function withdraw(){}

  /*
   * Constant functions
   */
  function currentEpoch()
    public
    view
    returns(uint256)
  {
    return block.number.sub(startBlock).div(EPOCH_LENGTH);
  }

}

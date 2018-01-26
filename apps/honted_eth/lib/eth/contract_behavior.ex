defmodule HonteD.Eth.ContractBehavior do
  @moduledoc """
  Interface of HonteD.Eth.Contract; implements reading from Geth
  """

  @type address :: binary
  @type bytes32 :: binary
  @type epoch :: pos_integer
  @type index :: non_neg_integer
  @type stake :: pos_integer

  @callback block_height() :: non_neg_integer()
  @callback syncing?() :: boolean()
  @callback read_validators(address) :: %{pos_integer() => [%HonteD.Validator{}]}
  @callback get_validator(address, epoch, index) :: {:ok, [{stake, bytes32, address}]}
  @callback balance_of(address, address) :: {:ok, non_neg_integer}
  @callback get_current_epoch(address) :: {:ok, epoch}
  @callback get_next_epoch_block_number(address) :: {:ok, pos_integer}
  @callback safety_limit_for_validators(address) :: {:ok, pos_integer}
  @callback max_number_of_validators(address) :: {:ok, pos_integer}
  @callback maturity_margin(address) :: {:ok, pos_integer}
  @callback epoch_length(address) :: {:ok, pos_integer}
  @callback start_block(address) :: {:ok, pos_integer}
  @callback unbonding_period(address) :: {:ok, pos_integer}
end

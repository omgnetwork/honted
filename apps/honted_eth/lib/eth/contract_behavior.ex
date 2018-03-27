#   Copyright 2018 OmiseGO Pte Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

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

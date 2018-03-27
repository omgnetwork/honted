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

defmodule HonteD.API.Tendermint.Tx do
  @moduledoc """
  Implementation of the transaction hashing algo.

  using specs from `tendermint/tendermint/types/tx.go` `Hash` function definition

  We're doing a ripemd160 of `tendermint/go-wire` encoded transaction bytes

  NOTE: this ideally shouldn't be here, but transaction hash isn't always exposed in tendermint's endpoints
  """

  def hash(tx_bytes) when is_binary(tx_bytes) do
    tx_size = byte_size(tx_bytes)
    tx_size_size = length(Integer.digits(tx_size, 256))
    :ripemd160
    |> :crypto.hash(<<tx_size_size, tx_size>> <> tx_bytes)
    |> Base.encode16
  end
end

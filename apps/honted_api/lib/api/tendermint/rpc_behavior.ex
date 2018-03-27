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

defmodule HonteD.API.Tendermint.RPCBehavior do
  @moduledoc """
  Interface of Tendermint's RPC api
  """

  @type result :: {:ok, map} | {:error, any}
  @type tx :: binary
  @type data :: any
  @type path :: binary
  @type hash :: binary
  @type client_ref() :: any

  @callback client() :: client_ref
  @callback broadcast_tx_async(client_ref, tx) :: result
  @callback broadcast_tx_sync(client_ref, tx) :: result
  @callback broadcast_tx_commit(client_ref, tx) :: result
  @callback abci_query(client_ref, data, path) :: result
  @callback tx(client_ref, hash) :: result
  @callback block(client_ref, height :: pos_integer) :: result
  @callback block_results(client_ref, height :: pos_integer) :: result
  @callback validators(client_ref) :: result
  @callback status(client_ref) :: result

end

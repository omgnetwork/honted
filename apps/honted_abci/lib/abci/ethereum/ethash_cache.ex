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

defmodule HonteD.ABCI.Ethereum.EthashCache do
  @moduledoc """
  Creates cache for Ethash
  """
  use Rustler, otp_app: :honted_abci, crate: "ethashcache"

  @dialyzer {:nowarn_function, __init__: 0} # supress warning in __init__ function in Rustler macro

  @doc """
  Returns cache used for constructing Ethereum DAG
  """
  def make_cache(_a), do: :erlang.nif_error(:nif_not_loaded)

end

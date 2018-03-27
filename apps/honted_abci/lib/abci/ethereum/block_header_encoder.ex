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

defmodule HonteD.ABCI.Ethereum.BlockHeaderEncoder do
  @moduledoc """
  Encodes block header without nonce and mix-hash components
  """
  alias HonteD.ABCI.Ethereum.BlockHeader

  @doc """
  Hashes RLP encoding of block header without mix and nonce.
  As in eq. 49 in yellowpaper
  """
  @spec pow_hash(%BlockHeader{}) :: BlockHeader.hash
  def pow_hash(block_header) do
    serialized_header = BlockHeader.serialize(block_header)
    header_no_nonce = header_without_nonce_and_mix(serialized_header)

    header_no_nonce
    |> ExRLP.encode
    |> :keccakf1600.sha3_256
  end

  defp header_without_nonce_and_mix(serialized_header) do
    [_nonce, _mix | tail] = Enum.reverse(serialized_header)
    Enum.reverse(tail)
  end

end

defmodule HonteD.ABCI.Ethereum.BlockHeaderEncoder do
  @moduledoc """
  Encodes block header for ethash PoW verification
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

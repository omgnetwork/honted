defmodule HonteD.ABCI.Ethereum.BlockHeaderEncoder do
  alias HonteD.ABCI.Ethereum.BlockHeader

  @doc """
  Hashes RLP encoding of block header without mix and nonce.
  As in eq. 49 in yellowpaper.
  """
  @spec pow_hash(%BlockHeader{}) :: BlockHeader.hash
  def pow_hash(block_header) do
    serialized_header = BlockHeader.serialize(block_header)
    [_nonce, _mix | tail] = Enum.reverse(serialized_header)

    Enum.reverse(tail)
    |> ExRLP.encode
    |> :keccakf1600.sha3_256
  end
end

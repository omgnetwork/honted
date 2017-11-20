defmodule HonteD.Transaction.Finality do
  @moduledoc """
  Transaction finality logic.
  If TendermintRPC is used (high-latency API), don't use those functions on the critical path.
  """

  # low latency

  @spec status(tx_height :: HonteD.block_height, HonteD.block_height, binary, binary)
    :: :finalized | :committed | :committed_unknown
  def status(tx_height, signed_off_height, signoff_hash, block_hash) do
    case {tx_height >= signed_off_height, signoff_hash == block_hash} do
      {true, true} -> :finalized
      {false, true} -> :committed
      {_, false} -> :committed_unknown
    end
  end

  # high latency

  def valid_signoff?(%HonteD.Transaction.SignOff{} = event, tendermint_module) do
    client = tendermint_module.client()
    with {:ok, blockhash} <- HonteD.API.Tools.get_block_hash(event.height, tendermint_module, client),
      do: event.hash == blockhash
  end


end

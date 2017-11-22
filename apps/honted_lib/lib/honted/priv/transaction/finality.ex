defmodule HonteD.Transaction.Finality do
  @moduledoc """
  Transaction finality logic.
  """

  @spec status(tx_height :: HonteD.block_height, HonteD.block_height, binary, binary)
    :: :finalized | :committed | :committed_unknown
  def status(tx_height, signed_off_height, signoff_hash, block_hash) do
    case {height_signed_off?(tx_height, signed_off_height),
          valid_signoff?(signoff_hash, block_hash)} do
      {true, true} -> :finalized
      {false, true} -> :committed
      {_, false} -> :committed_unknown
    end
  end

  @spec split_finalized_events(Qex.t({HonteD.block_height, any}), HonteD.block_height)
  :: {[{HonteD.block_height, any}], [{HonteD.block_height, any}]}
  def split_finalized_events(queue, signed_off_height) do
    # for a given token will pop the events committed earlier, that are before the signed_off_height
    is_older = fn({h, _event}) -> height_signed_off?(h, signed_off_height) end
    Enum.split_while(queue, is_older)
  end

  @spec valid_signoff?(HonteD.block_hash, HonteD.block_hash) :: boolean
  def valid_signoff?(signed_hash, real_block_hash), do: signed_hash == real_block_hash

  @spec height_signed_off?(HonteD.block_height, HonteD.block_height) :: boolean
  defp height_signed_off?(height, signed_off), do: height <= signed_off

end

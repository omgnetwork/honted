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

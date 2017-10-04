defmodule HonteD.API do
  @moduledoc """
  Implements the API to be exposed via various means: JSONRPC2.0, cli, other?

  Should abstract out all Tendermint-related stuff
  """
  def create_send_transaction(asset, amount, from, to)
  when is_binary(asset) and
       is_integer(amount) and
       is_binary(from) and
       is_binary(to) do
    HonteD.TxCodec.encode([:send, asset, amount, from, to])
  end

  def submit_transaction(transaction) do
    case HonteD.TendermintRPC.broadcast_tx_sync(transaction) do
      {:ok, %{"code" => code, "hash" => hash}} when code in [0, 3] ->
        {:ok, hash}  # either submitted or duplicate
      result -> result
    end
  end

end

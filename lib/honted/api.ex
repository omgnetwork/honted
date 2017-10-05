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
    case HonteD.TendermintRPC.abci_query("", "/nonces/#{from}") do
      {:ok, %{"response" => %{"code" => 0, "value" => nonce}}} ->
        HonteD.TxCodec.encode([Base.decode16!(nonce), :send, asset, amount, from, to])
      result -> result
    end
  end

  def submit_transaction(transaction) do
    case HonteD.TendermintRPC.broadcast_tx_sync(transaction) do
      {:ok, %{"code" => code, "hash" => hash}} when code in [0, 3] ->
        {:ok, hash}  # either submitted or duplicate
      result -> result
    end
  end

end

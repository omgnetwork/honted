defmodule HonteD.API do
  @moduledoc """
  Implements the API to be exposed via various means: JSONRPC2.0, cli, other?

  Should abstract out all Tendermint-related stuff
  """
  @spec create_send_transaction(binary, pos_integer, binary, binary) :: {:ok, binary} | any
  def create_send_transaction(asset, amount, from, to)
  when is_binary(asset) and
       is_integer(amount) and
       amount > 0 and
       is_binary(from) and
       is_binary(to) do
    case HonteD.TendermintRPC.abci_query("", "/nonces/#{from}") do
      {:ok, %{"response" => %{"code" => 0, "value" => nonce}}} ->
        HonteD.TxCodec.encode([Base.decode16!(nonce), :send, asset, amount, from, to])
      result -> result
    end
  end

  @spec submit_transaction(binary) :: {:ok, binary} | any
  def submit_transaction(transaction) do
    case HonteD.TendermintRPC.broadcast_tx_sync(transaction) do
      {:ok, %{"code" => code, "hash" => hash}} when code in [0, 3] ->
        {:ok, hash}  # either submitted or duplicate
      result -> result
    end
  end

  @spec query_balance(binary, binary) :: {:ok, non_neg_integer} | any
  def query_balance(asset, address)
  when is_binary(asset) and
       is_binary(address) do
    case HonteD.TendermintRPC.abci_query("", "/accounts/#{asset}/#{address}") do
      {:ok, %{"response" => %{"code" => 0, "value" => balance_enc}}} ->
        {balance, ""} = Integer.parse(Base.decode16!(balance_enc))
        {:ok, balance}
      result -> result
    end
  end

end

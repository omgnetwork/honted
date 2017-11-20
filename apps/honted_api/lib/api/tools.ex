defmodule HonteD.API.Tools do
  @moduledoc """
  Shared functionality used by HonteD.API _not to be auto-exposed_
  """
  
  alias HonteD.API.TendermintRPC
  
  @doc """
  Uses a TendermintRPC `client` to get the current nonce for the `from` address. Returns raw Tendermint response
  in case of any failure
  """
  def get_nonce(client, from) do
    get_and_decode(client, "/nonces/#{from}")
  end
  
  @doc """
  Uses a TendermintRPC `client` to the issuer for a token
  """
  def get_issuer(client, token) do
    get_and_decode(client, "/tokens/#{token}/issuer")
  end
  
  @doc """
  Uses a TendermintRPC `client` to query anything from the abci and decode to map
  """
  def get_and_decode(client, key) do
    rpc_response = TendermintRPC.abci_query(client, "", key)
    with {:ok, %{"response" => %{"code" => 0, "value" => encoded}}} <- rpc_response,
         do: Poison.decode(encoded)
  end

  @doc """
  Enriches the standards Tendermint tx information with a HonteD-specific status flag
    :failed, :pending, :committed, :finalized, :committed_unknown
  """
  def append_status(tx_info, client) do
    tx_info
    |> Map.put(:status, get_tx_status(tx_info, client))
  end

  defp get_tx_status(tx_info, client) do
    with :committed <- get_tx_tendermint_status(tx_info),
         do: HonteD.TxCodec.decode!(tx_info["tx"])
             |> get_sign_off_status_for_committed(client, tx_info["height"])
  end

  def get_block_hash(height, tendermint_module, client) do
    case tendermint_module.block(client, height) do
      {:ok, block} -> {:ok, block_hash(block)}
      nil -> false
    end
  end

  defp get_tx_tendermint_status(tx_info) do
    case tx_info do
      %{"height" => _, "tx_result" => %{"code" => 0, "data" => "", "log" => ""}} -> :committed
      # NOTE not sure the following scenarios are possible!
      %{"tx_result" => %{"code" => 0, "data" => "", "log" => ""}} -> :pending
      # successful look up of failed tx
      %{"tx_result" => _} -> :failed
    end
  end

  defp get_sign_off_status_for_committed(%HonteD.Transaction.SignedTx{raw_tx: %HonteD.Transaction.Send{} = tx},
                                         client,
                                         tx_height) do
    {:ok, issuer} = get_issuer(client, tx.asset)
    {:ok, blockhash} = get_block_hash(tx_height, HonteD.TendermintRPC, client)

    case get_and_decode(client, "/sign_offs/#{issuer}") do
      {:ok, %{"response" => %{"code" => 1}}} ->
        :committed # FIXME: handle this case in a more appropriate manner
      {:ok, %{"height" => sign_off_height, "hash" => sign_off_hash}} ->
        HonteD.Transaction.Finality.status(tx_height, sign_off_height, sign_off_hash, blockhash)
    end
  end
  defp get_sign_off_status_for_committed(_, _, _), do: :committed

  # private

  defp block_hash(block) do
    block["block_meta"]["block_id"]["hash"]
  end



end

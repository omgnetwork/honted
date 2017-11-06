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
    rpc_response = TendermintRPC.abci_query(client, "", "/nonces/#{from}")
    with {:ok, %{"response" => %{"code" => 0, "value" => nonce_encoded}}} <- rpc_response,
         do: TendermintRPC.from_json(nonce_encoded)
  end
  
  def get_issuer(client, token) do
    rpc_response = TendermintRPC.abci_query(client, "", "/tokens/#{token}/issuer")
    with {:ok, %{"response" => %{"code" => 0, "value" => issuer_encoded}}} <- rpc_response,
         do: TendermintRPC.from_json(issuer_encoded)
  end
  
  def get_total_supply(client, token) do
    rpc_response = TendermintRPC.abci_query(client, "", "/tokens/#{token}/total_supply")
    with {:ok, %{"response" => %{"code" => 0, "value" => supply_encoded}}} <- rpc_response,
         do: TendermintRPC.from_json(supply_encoded)
  end
  
  def get_sign_off(client, address) do
    rpc_response = TendermintRPC.abci_query(client, "", "/sign_offs/#{address}")
    with {:ok, %{"response" => %{"code" => 0, "value" => supply_encoded}}} <- rpc_response,
         do: TendermintRPC.from_json(supply_encoded)
  end
  
  @doc """
  ENriches the standard Tendermint tx information with decoded form of the transaction
  """
  def append_decoded(tx_info, tx) do
    # adding a convenience field to preview the tx
    case TendermintRPC.to_binary({:base64, tx}) do
      {:ok, decoded} -> Map.put(tx_info, :decoded_tx, decoded)
      _ -> Map.put(tx_info, :decoded_tx, :decode_failed)
    end
  end

  @doc """
  Enriches the standards Tendermint tx information with a HonteD-specific status flag
    :failed, :pending, :committed, :finalized
  """
  def append_status(tx_info, client) do
    tx_info
    |> Map.put(:status, get_tx_status(tx_info, client))
  end

  defp get_tx_status(tx_info, client) do
    with :committed <- get_tx_tendermint_status(tx_info),
         do: HonteD.TxCodec.decode!(tx_info.decoded_tx)
             |> get_sign_off_status_for_committed(client, tx_info["height"])
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
    {:ok, sign_off} = get_sign_off(client, issuer) 
      
    case sign_off do
      "" -> :committed # FIXME: handle this case in a more appropriate manner
      %{"height" => sign_off_height} -> if sign_off_height >= tx_height, do: :finalized, else: :committed
    end
  end
  defp get_sign_off_status_for_committed(_, _, _), do: :committed
  
end

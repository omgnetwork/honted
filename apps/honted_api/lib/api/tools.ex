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
         do: TendermintRPC.to_int(nonce_encoded)
  end
  
  def get_issuer(client, token) do
    rpc_response = TendermintRPC.abci_query(client, "", "/tokens/#{token}/issuer")
    with {:ok, %{"response" => %{"code" => 0, "value" => issuer_encoded}}} <- rpc_response,
         do: TendermintRPC.to_binary(issuer_encoded)
  end
  
  def get_total_supply(client, token) do
    rpc_response = TendermintRPC.abci_query(client, "", "/tokens/#{token}/total_supply")
    with {:ok, %{"response" => %{"code" => 0, "value" => supply_encoded}}} <- rpc_response,
         do: TendermintRPC.to_int(supply_encoded)
  end
end

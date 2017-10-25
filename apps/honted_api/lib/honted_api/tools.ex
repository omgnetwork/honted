defmodule HonteDAPI.Tools do
  @moduledoc """
  Shared functionality used by HonteDAPI _not to be auto-exposed_
  
  TODO: we should avoid having "tools" and "utils" modules, but where would this belong?
  """
  
  alias HonteDAPI.TendermintRPC
  
  @doc """
  Uses a TendermintRPC `client` to get the current nonce for the `from` address. Returns raw Tendermint response
  in case of any failure
  """
  def get_nonce(client, from) do
    rpc_response = TendermintRPC.abci_query(client, "", "/nonces/#{from}")
    with {:ok, %{"response" => %{"code" => 0, "value" => nonce_encoded}}} <- rpc_response,
         {:ok, string_nonce} <- Base.decode16(nonce_encoded),
         {int_nonce, ""} <- Integer.parse(string_nonce),
         do: {:ok, int_nonce}
  end
  
  def get_issuer(client, token) do
    rpc_response = TendermintRPC.abci_query(client, "", "/tokens/#{token}/issuer")
    with {:ok, %{"response" => %{"code" => 0, "value" => issuer_encoded}}} <- rpc_response,
         {:ok, decoded} <- Base.decode16(issuer_encoded),
         do: {:ok, decoded}
  end
  
  def get_total_supply(client, token) do
    rpc_response = TendermintRPC.abci_query(client, "", "/tokens/#{token}/total_supply")
    with {:ok, %{"response" => %{"code" => 0, "value" => supply_encoded}}} <- rpc_response,
         {:ok, decoded} <- Base.decode16(supply_encoded),
         {supply, ""} <- Integer.parse(decoded),
         do: {:ok, supply}
  end
end

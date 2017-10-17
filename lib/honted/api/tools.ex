defmodule HonteD.API.Tools do
  @moduledoc """
  Shared functionality used by HonteD.API _not to be auto-exposed_
  
  TODO: we should avoid having "tools" and "utils" modules, but where would this belong?
  """
  
  alias HonteD.TendermintRPC
  
  @doc """
  Uses a TendermintRPC `client` to get the current nonce for the `from` address. Returns raw Tendermint response
  in case of any failure
  """
  def get_nonce(client, from) do
    result = TendermintRPC.abci_query(client, "", "/nonces/#{from}")
    with {:ok, %{"response" => %{"code" => 0, "value" => nonce}}} <- result,
         {:ok, string_nonce} <- Base.decode16(nonce),
         {int_nonce, ""} <- Integer.parse(string_nonce)
    do 
      int_nonce
    else 
      _ -> result
    end
  end
end

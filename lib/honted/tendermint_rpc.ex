defmodule HonteD.TendermintRPC do
  @moduledoc """
  Wraps Tendermints RPC to allow to broadcast transactions from Elixir functions, inter alia
  """
  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://localhost:46657"
  plug Tesla.Middleware.JSON

  def broadcast_tx_sync(tx) do
    _result_of get("/broadcast_tx_sync", query: [tx: "\"" <> tx <> "\""])
  end

  defp _result_of(response) do
    case response.body do
      %{"error" => "", "result" => result} -> {:ok, result}
      %{"error" => error, "result" => ""} -> {:error, error}
    end
  end
end

# TODO: consider alternative version, but I cannot get the tendermint json querries to execute
# defmodule HonteD.TendermintRPC do
#   alias JSONRPC2.Clients.HTTP
#
#   @url "http://localhost:46657/"
#
#   def broadcast_tx_sync(tx) do
#     HTTP.call(@url, "broadcast_tx_sync", [tx])
#   end
# end

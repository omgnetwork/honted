defmodule HonteD.TendermintRPC do
  @moduledoc """
  Wraps Tendermints RPC to allow to broadcast transactions from Elixir functions, inter alia
  """
  use Tesla

  def client() do
    rpc_port = Application.get_env(:honted, :rpc_port)
    Tesla.build_client [
      {Tesla.Middleware.BaseUrl, "http://localhost:#{rpc_port}"},
      Tesla.Middleware.JSON
    ]
  end

  def broadcast_tx_sync(client, tx) do
    _result_of get(client, "/broadcast_tx_sync", query: [tx: "\"" <> tx <> "\""])
  end

  def abci_query(client, data, path) do
    _result_of get(client, "abci_query", query: [
      data: "\"#{data}\"",
      path: "\"#{path}\""
    ])
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

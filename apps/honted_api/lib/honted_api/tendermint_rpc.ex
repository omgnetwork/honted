defmodule HonteDAPI.TendermintRPC do
  @moduledoc """
  Wraps Tendermints RPC to allow to broadcast transactions from Elixir functions, inter alia
  """
  use Tesla

  def client() do
    rpc_port = Application.get_env(:honted_api, :tendermint_rpc_port)
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

  def tx(client, hash) do
    _result_of get(client, "tx", query: [
      hash: "0x#{hash}",
      prove: "false"
    ])
  end

  defp _result_of(response) do
    case response.body do
      %{"error" => "", "result" => result} -> {:ok, result}
      %{"error" => error, "result" => nil} -> {:error, error}
    end
  end
end

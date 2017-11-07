defmodule HonteD.API.TendermintRPC do
  @moduledoc """
  Wraps Tendermints RPC to allow to broadcast transactions from Elixir functions, inter alia
  
  This should only depend on Tendermint rpc's specs, never on any of our stuff
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
    decode get(client, "/broadcast_tx_sync", query: encode(
      tx: tx
    ))
  end

  def broadcast_tx_commit(client, tx) do
    decode get(client, "/broadcast_tx_commit", query: encode(
      tx: tx
    ))
  end

  def abci_query(client, data, path) do
    decode get(client, "abci_query", query: encode(
      data: data,
      path: path
    ))
  end

  def tx(client, hash) do
    decode get(client, "tx", query: encode(
      hash: {:hash, hash},
      prove: false
    ))
  end
  
  ### convenience functions to decode fields returned from Tendermint rpc
  
  def to_int(value) do
    with {:ok, decoded} <- Base.decode16(value),
         {parsed, ""} <- Integer.parse(decoded),
         do: {:ok, parsed}    
  end
  def to_binary({:base64, value}) do
    Base.decode64(value)
  end
  def to_binary(value) do
    Base.decode16(value)
  end
  def to_list(value, length) do
    with {:ok, decoded} <- Base.decode16(value),
         # translate raw output from abci by cutting into 40-char-long ascii sequences
         do: {:ok, decoded |> String.codepoints |> Enum.chunk_every(length) |> Enum.map(&Enum.join/1)}
  end
  
  ### private

  defp decode(response) do
    case response.body do
      %{"error" => "", "result" => result} -> {:ok, result}
      %{"error" => error, "result" => nil} -> {:error, error}
    end
  end
  
  defp encode(arglist) when is_list(arglist) do
    arglist
    |> Enum.map(fn {argname, argval} -> {argname, encode(argval)} end)
  end
  defp encode({:hash, raw}) when is_binary(raw), do: "0x#{raw}"
  defp encode(raw) when is_binary(raw), do: "\"#{raw}\""
  defp encode(raw) when is_boolean(raw), do: to_string(raw)
  
end

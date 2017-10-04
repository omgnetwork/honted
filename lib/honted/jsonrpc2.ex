defmodule HonteD.JSONRPC2.Server.Handler do
  @moduledoc """
  Exposes HonteD.API via jsonrpc 2.0 over http
  """
  use JSONRPC2.Server.Handler

  def handle_request("createSendTransaction", params) do
    case params do
      %{"asset" => asset,
        "amount" => amount,
        "from" => from,
        "to" => to} -> HonteD.API.create_send_transaction(asset, amount, from, to)
      _ -> throw :invalid_params
    end
  end
end

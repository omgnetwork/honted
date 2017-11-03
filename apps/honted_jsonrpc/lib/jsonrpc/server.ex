defmodule HonteD.JSONRPC.Server.Handler do
  @moduledoc """
  Exposes HonteD.API via jsonrpc 2.0 over HTTP. It leverages the generic HonteD.JSONRPC.Exposer convenience module
  """
  use JSONRPC2.Server.Handler

  def handle_request(method, params) do
    HonteD.JSONRPC.Exposer.handle_request_on_api(method, params, HonteD.API)
  end

end

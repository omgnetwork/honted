defmodule HonteD.JSONRPC.Server.Handler do
  @moduledoc """
  Exposes HonteD.API via jsonrpc 2.0 over HTTP.

  Internally uses HonteD.API.ExposeSpec macro to expose function argument names
  so that pairing between JSON keys and arg names becomes possible.

  Note: it ignores extra args and does not yet handle functions
  of same name but different arity
  """
  use JSONRPC2.Server.Handler

  @spec handle_request(method :: binary, params :: %{required(binary) => any}) :: any
  def handle_request(method, params) do
    with {:ok, fname, args} <- HonteD.API.RPCTranslate.to_fa(method, params, HonteD.API.get_specs()),
         {:ok, result} <- apply_call(HonteD.API, fname, args)
    do
      result
    else
      error -> throw error # JSONRPC requires to throw whatever fails, for proper handling of jsonrpc errors
    end
  end

  defp apply_call(module, fname, args) do
    case :erlang.apply(module, fname, args) do
      # FIXME: Mapping between Elixir-style errors
      #        and JSONRPC errors is needed here.
      #        Code below is a stub.
      {:ok, any} -> {:ok, any}
      {:error, any} -> {:internal_error, any}
    end
  end

end

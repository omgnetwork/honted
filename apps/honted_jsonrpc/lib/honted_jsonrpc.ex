defmodule HonteDJSONRPC.Server.Handler do
  @moduledoc """
  Exposes HonteDAPI via jsonrpc 2.0 over HTTP.

  Internally uses HonteDAPI.ExposeSpec macro to expose function argument names
  so that pairing between JSON keys and arg names becomes possible.

  Note: it ignores extra args and does not yet handle functions
  of same name but different arity
  """
  use JSONRPC2.Server.Handler

  @spec handle_request(method :: binary, params :: %{required(binary) => any}) :: any
  def handle_request(method, params) do
    with {:ok, fname, args} <- HonteDAPI.RPCTranslate.to_fa(method, params, HonteDAPI.get_specs()),
      do: apply_call(HonteDAPI, fname, args)
  end

  defp apply_call(module, fname, args) do
    case :erlang.apply(module, fname, args) do
      # FIXME: Mapping between Elixir-style errors
      #        and JSONRPC errors is needed here.
      #        Code below is a stub.
      {:ok, any} -> any
      {:error, any} -> {:internal_error, any}
    end
  end

end

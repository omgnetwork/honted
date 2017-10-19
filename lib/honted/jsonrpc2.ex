defmodule HonteD.JSONRPC2.Server.Handler do
  @moduledoc """
  Exposes HonteD.API via jsonrpc 2.0 over HTTP.

  Internally uses ExposeSpec macro to expose function argument names
  so that pairing between JSON keys and arg names becomes possible.

  Note: it ignores extra args and does not yet handle functions
  of same name but different arity
  """
  use JSONRPC2.Server.Handler

  @spec handle_request(endpoint :: binary, params :: %{required(binary) => any}) :: any
  def handle_request(endpoint, params) do
    with {:ok, fname, args} <- RPCTranslate.to_fa(endpoint, params, HonteD.API.get_specs()),
      do: apply_call(HonteD.API, fname, args)
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

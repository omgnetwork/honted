defmodule HonteD.JSONRPC.Exposer do
  @moduledoc """
  This module contains a helper function to be called within JSONRPC Handlers `handle_request`
  
  It takes the original data request and channels it to a specific API exposed using HonteD.API.ExposeSpec

  Internally uses HonteD.API.ExposeSpec macro to expose function argument names
  so that pairing between JSON keys and arg names becomes possible.

  Note: it ignores extra args and does not yet handle functions
  of same name but different arity
  """
  
  @spec handle_request_on_api(method :: binary, 
                              params :: %{required(binary) => any},
                              api :: atom) :: any
  def handle_request_on_api(method, params, api) do
    with {:ok, fname, args} <- HonteD.API.RPCTranslate.to_fa(method, params, api.get_specs()),
         {:ok, result} <- apply_call(api, fname, args)
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

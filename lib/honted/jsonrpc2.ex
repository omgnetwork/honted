defmodule HonteD.JSONRPC2.Server.Handler do
  @moduledoc """
  Exposes HonteD.API via jsonrpc 2.0 over HTTP.

  Internally uses ExposeSpec macro to expose function argument names
  so that pairing between JSON keys and arg names becomes possible.

  Note: it ignores extra args and does not yet handle functions
  of same name but different arity
  """
  use JSONRPC2.Server.Handler

  @api HonteD.API

  @type function_name :: binary
  @type arg_name :: binary
  @type json_args :: %{required(arg_name) => any}
  @type rpc_error :: :method_not_found | {:invalid_params, %{}}
  @type spec :: any

  @spec handle_request(endpoint :: function_name, params :: json_args) :: any
  def handle_request(endpoint, params) do
    with {:ok, fname, args} = translate_request(endpoint, params, @api._spec()),
         do: apply_call(@api, fname, args)
  end

  @spec translate_request(endpoint :: function_name, params :: json_args, spec :: spec)
        :: {:ok, atom, list(any)} | rpc_error
  def translate_request(endpoint, params, spec) do
    with {:ok, fname} <- existing_atom(endpoint),
         :ok <- is_exposed(fname, spec),
         {:ok, args} <- get_args(fname, params, spec),
         do: {:ok, fname, args}
  end

  @spec existing_atom(endpoint :: function_name) :: {:ok, atom} | :method_not_found
  def existing_atom(endpoint) do
    try do
      {:ok, String.to_existing_atom(endpoint)}
    rescue
      ArgumentError -> :method_not_found
    end
  end

  @spec is_exposed(fname :: atom, spec :: spec) :: {:ok, atom} | :method_not_found
  defp is_exposed(fname, spec) do
    case fname in Map.keys(spec) do
      true -> :ok
      false -> :method_not_found
    end
  end

  @spec get_args(fname :: atom, params :: json_args, spec :: spec)
        :: {:ok, list(any)} | {:invalid_params, %{}}
  defp get_args(fname, params, spec) do
    validate_args = fn({name, _} = argspec, list) ->
      case Map.get(params, Atom.to_string(name)) do
        nil -> {:halt, {:missing_arg, argspec}}
        value -> {:cont, list ++ [value]}
      end
    end
    case Enum.reduce_while(spec[fname].args, [], validate_args) do
      {:missing_arg, {name, type}} ->
        {:invalid_params, %{msg: "Please provide parameter `#{name}` of type `#{inspect type}`"}}
      args ->
        {:ok, args}
    end
  end

  defp apply_call(module, fname, args) do
    :erlang.apply(module, fname, args)
  end

end

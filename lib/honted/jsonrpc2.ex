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

  @spec handle_request(endpoint :: function_name, params :: json_args) :: any
  def handle_request(endpoint, params) do
    with {:ok, fname} <- existing_atom(endpoint),
         :ok <- is_exposed(fname),
         {:ok, args} <- get_args(fname, params),
         do: apply_call(fname, args)
  end

  @spec existing_atom(endpoint :: function_name) :: {:ok, atom} | :method_not_found
  def existing_atom(endpoint) do
    try do
      {:ok, String.to_existing_atom(endpoint)}
    rescue
      ArgumentError -> :method_not_found
    end
  end

  @spec is_exposed(fname :: atom) :: {:ok, atom} | :method_not_found
  defp is_exposed(fname) do
    case fname in Map.keys(@api._spec()) do
      true -> :ok
      false -> :method_not_found
    end
  end

  @spec get_args(fname :: atom, params :: json_args) :: {:ok, list(any)} | {:invalid_params, %{}}
  defp get_args(fname, params) do
    argspec = @api._spec()[fname].args
    validate_args = fn({name, _} = spec, list) ->
      case Map.get(params, Atom.to_string(name)) do
        nil -> {:halt, {:missing_arg, spec}}
        value -> {:cont, list ++ [value]}
      end
    end
    case Enum.reduce_while(argspec, [], validate_args) do
      {:missing_arg, {name, type}} ->
        {:invalid_params, %{msg: "Please provide parameter `#{name}` of type `#{inspect type}`"}}
      args ->
        {:ok, args}
    end
  end

  defp apply_call(fname, args) do
    :erlang.apply(@api, fname, args)
  end

end

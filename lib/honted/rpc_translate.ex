defmodule RPCTranslate do
  @moduledoc """
  Translate JSONRPC2 call to a form that can be executed with :erlang.apply/3
  Returns JSONRPC2-specific error values if there is a problem.
  """

  @type function_name :: binary
  @type arg_name :: binary
  @type spec :: any
  @type json_args :: %{required(arg_name) => any}
  @type rpc_error :: :method_not_found | {:invalid_params, %{}}

  @spec to_fa(endpoint :: function_name, params :: json_args, spec :: spec)
        :: {:ok, atom, list(any)} | rpc_error
  def to_fa(endpoint, params, spec) do
    with {:ok, fname} <- existing_atom(endpoint),
         :ok <- is_exposed(fname, spec),
         {:ok, args} <- get_args(fname, params, spec),
         do: {:ok, fname, args}
  end

  @spec existing_atom(endpoint :: function_name) :: {:ok, atom} | :method_not_found
  defp existing_atom(endpoint) do
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
  defp get_args(fname, params, spec) when is_map(params) do
    validate_args = fn({name, _} = argspec, list) ->
      case Map.get(params, Atom.to_string(name)) do
        nil -> {:halt, {:missing_arg, argspec}}
        value -> {:cont, list ++ [value]}
      end
    end
    case Enum.reduce_while(spec[fname].args, [], validate_args) do
      {:missing_arg, {name, type}} ->
        msg = "Please provide parameter `#{name}` of type `#{inspect type}`"
        throw {:invalid_params, %{msg: msg}}
      args ->
        {:ok, args}
    end
  end
  defp get_args(_, _, _) do
    throw {:invalid_params, %{msg: "params should be a JSON key-value pair array"}}
  end

end

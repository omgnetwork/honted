defmodule RPCTranslate do
  @moduledoc """
  Translate JSONRPC2 call to a form that can be executed with :erlang.apply/3
  Returns JSONRPC2-specific error values if there is a problem.
  """

  @type function_name :: binary
  @type arg_name :: binary
  @type spec :: ExposeSpec.spec()
  @type json_args :: %{required(arg_name) => any}
  @type rpc_error :: :method_not_found | {:invalid_params, %{}}


  @doc """
  `to_fa/3` transforms JSONRPC2 method and params to Elixir's Function and Arguments,
  since the naming. See also type mfa() in Elixir's typespecs.
  """
  @spec to_fa(method :: function_name, params :: json_args, spec :: spec)
        :: {:ok, atom, list(any)} | rpc_error
  def to_fa(method, params, spec, on_match \\ &on_match_default/3) do
    with {:ok, fname} <- existing_atom(method),
         :ok <- is_exposed(fname, spec),
         {:ok, args} <- get_args(fname, params, spec, on_match),
         do: {:ok, fname, args}
  end

  defp on_match_default(_name, _type, value), do: value

  @spec existing_atom(method :: function_name) :: {:ok, atom} | :method_not_found
  defp existing_atom(method) do
    try do
      {:ok, String.to_existing_atom(method)}
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

  @spec get_args(fname :: atom, params :: json_args, spec :: spec, on_match :: fun())
        :: {:ok, list(any)} | {:invalid_params, %{}}
  defp get_args(fname, params, spec, on_match) when is_map(params) do
    validate_args = fn({name, type} = argspec, list) ->
      case Map.get(params, Atom.to_string(name)) do
        nil ->
          {:halt, {:missing_arg, argspec}}
        value ->
          value = on_match.(name, type, value)
          {:cont, list ++ [value]}
      end
    end
    case Enum.reduce_while(spec[fname].args, [], validate_args) do
      {:missing_arg, {name, type}} ->
        msg = "Please provide parameter `#{name}` of type `#{inspect type}`"
        throw {:invalid_params, %{msg: msg, name: name, type: type}}
      args ->
        {:ok, args}
    end
  end
  defp get_args(_, _, _, _) do
    throw {:invalid_params, %{msg: "params should be a JSON key-value pair array"}}
  end

end

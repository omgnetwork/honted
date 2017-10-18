defmodule ExposeSpec do
  @moduledoc """
  `use ExposeSpec` to expose all @spec in the runtime via YourModule._spec()

  There is undocumented Kernel.Typespec.beam_specs/1 which exposes similar
  functionality. Unfortunately it is considered to be unstable.

  FIXME: functions with the same name but different arity are not yet supported
  FIXME: spec AST parser is primitive, it does not handle all correct possibilities

  Avoid multiple arity functions
  # @spec arity(x :: integer, y :: integer) :: integer
  # def arity(x, y), do: x + y
  # @spec arity(x :: integer) :: integer
  # def arity(x), do: x + 2

  Avoid aliasing of types in specs - it will get silently dropped by AST parser
  # @spec aliased(x) :: x when x: integer
  # def aliased(x) do
  # x + 1
  # end
  """

  def quoted_spec_to_kv({:spec, {_, _, []}, _}) do
    :incomplete_spec
  end
  def quoted_spec_to_kv({:spec, {:::, _, body_return_pair}, _}) do
    parse_body_ret_pair(body_return_pair)
  end
  def quoted_spec_to_kv({:spec, {_name, _, _args}, _}) do
    # Can safely ignore this spec since it does not define return type.
    # It will be caught by compiler during next stage of compilation.
    :incomplete_spec
  end

  def parse_body_ret_pair([{name, _line, args}, output_tuple]) do
    body(name, args)
    |> add_return_type(output_tuple)
  end

  def body(name, args) do
    argkv = parse_args(args)
    %{name: name,
      arity: length(argkv),
      args: argkv}
  end

  def add_return_type(res, term) do
    return_type = parse_term(term)
    Map.put(res, :returns, return_type)
  end

  def parse_term(atom) when is_atom(atom), do: atom
  def parse_term({el1, el2}), do: {parse_term(el1), parse_term(el2)}
  def parse_term({:|, _, alts}), do: parse_alternative(alts)
  def parse_term({atom, _, :nil}) when is_atom(atom), do: atom

  def parse_alternative(list) do
    alts = for term <- list, do: parse_term(term)
    {:alternative, alts}
  end

  def parse_args(args) do
    # keyword list (not a map) because we care about order!
    for arg <- args, do: quoted_arg_to_kv(arg)
  end

  def quoted_arg_to_kv({:::, _, [argname, argtype]}) do
    {parse_term(argname), parse_term(argtype)}
  end
  # in correct spec this is always a argtype, never an argname
  def quoted_arg_to_kv({argtype, _, nil}) do
    argtype
  end

  # Sanity check since functions of the same name
  # but different arity are not yet handled.
  def arity_sanity_check(list) do
    names = for {name, _} <- list, do: name
    testresult = length(Enum.uniq(names)) != length(names)
    tag = :problem_with_arity
    {^tag, false} = {tag, testresult}
  end

  defmacro __using__(_opts) do
    quote do
      import ExposeSpec

      @before_compile ExposeSpec
    end
  end

  defmacro __before_compile__(env) do
    module = env.module
    nice_spec = Module.get_attribute(module, :spec)
      |> Enum.map(&quoted_spec_to_kv/1)
      |> Enum.filter(fn(x) -> x != :incomplete_spec end)
      |> Enum.map(fn(map) -> {map[:name], map} end)
    arity_sanity_check(nice_spec)
    escaped = Macro.escape(Map.new(nice_spec))
    quote do
      def _spec, do: unquote(escaped)
    end
  end
end

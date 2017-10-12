defmodule ExampleTest do
  use ExUnit.Case

  defmodule ExposeSpecTest do

    use ExposeSpec

    @spec basic(x :: integer, y :: integer) :: integer
    def basic(x, y) do
      x + y
    end

    @spec complex_return(x :: integer) :: {:ok, integer}
    def complex_return(x) do
      {:ok, x + 2}
    end

    # lazy programmer: mentions type but not the variable name, parses OK
    @spec lazy(integer) :: {:ok, integer}
    def lazy(x) do
      {:ok, x + 2}
    end

    # parse result here is a bit ugly because series
    # of alternatives are nested in quoted (AST)
    @spec alts(x :: {:ok, integer | float}) :: {:ok, integer} | :error | :error2
    def alts(x) do
      {:ok, x + 2}
    end

    # this one is too complex - will be just dropped by ExposeSpec
    @spec aliased(x) :: x when x: integer
    def aliased(x) do
      x + 1
    end


    # # next two should crash ExposeSpec on assert
    # @spec arity(x :: integer, y :: integer) :: integer
    # def arity(x, y), do: x + y
    # @spec arity(x :: integer) :: integer
    # def arity(x), do: x + 2

    # # will not compile, should not crash ExposeSpec
    # @spec underdefined(x) :: :ok
    # def underdefined(x) do
    #   :ok
    # end

    # # will not compile, should not crash ExposeSpec
    # @spec crash(x :: integer, y :: integer)
    # def crash(x, y) do
    #   throw(:yep)
    # end

  end

  test "cleans up spec AST to kv form" do
    tc1 = {:spec, {:::, [line: 7],
                   [{:add, [line: 7],
                     [{:::, [line: 7],
                       [{:x, [line: 7], nil},
                        {:integer, [line: 7], nil}]},
                      {:::, [line: 7],
                       [{:y, [line: 7], nil},
                        {:integer, [line: 7], nil}]}]},
                    {:integer, [line: 7], nil}]
                  },
           {Test, {7, 1}}}
    e1 = %{name: :add, arity: 2, args: [x: :integer, y: :integer], returns: :integer}
    assert e1 == ExposeSpec.quoted_spec_to_kv(tc1)
  end

  test "expected list of parsed specs" do
    assert [:alts, :basic, :complex_return, :lazy] == Enum.sort(Map.keys(ExposeSpecTest._spec))
  end

  test "test one spec" do
    assert ExposeSpecTest._spec.lazy ==
      %{args: [:integer], arity: 1, name: :lazy, returns: {:ok, :integer}}
  end
end

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

    # lazy programmer: mentions type but not the variable name, parses OK
    @spec lists(integer) :: {:ok, [integer]}
    def lists(x) do
      {:ok, [x + 2]}
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

    @spec triple(x :: {integer, integer, integer}) :: :ok
    def triple(_x) do
      :ok
    end

  end

  test "expected list of parsed specs" do
    assert [:alts, :basic, :complex_return, :lazy, :lists, :triple] ==
      Enum.sort(Map.keys(ExposeSpecTest.get_specs()))
  end

  test "test one spec" do
    assert ExposeSpecTest.get_specs().lazy ==
      %{args: [:integer], arity: 1, name: :lazy, returns: {:ok, :integer}}
  end

  test "test triple" do
    assert ExposeSpecTest.get_specs().triple ==
      %{args: [{:x, {:integer, :integer, :integer}}], arity: 1, name: :triple, returns: :ok}
  end
end

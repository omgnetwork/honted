defmodule HonteD.JSONRPC2.Server.HandlerTest do
  use ExUnit.Case

  defmodule ExampleAPI do
    use ExposeSpec

    @spec is_even_N(x :: integer) :: boolean | {:error, :badarg}
    def is_even_N(x) when x > 0 and is_integer(x) do
      {:ok, rem(x, 2) == 0}
    end
    def is_even_N(_) do
      {:error, :badarg}
    end
  end

  # SUT (System Under Test):
  defmodule ExampleHandler do
    use JSONRPC2.Server.Handler

    @spec handle_request(method :: binary, params :: %{required(binary) => any}) :: any
    def handle_request(method, params) do
      with {:ok, fname, args} <- RPCTranslate.to_fa(method, params, ExampleAPI.get_specs()),
        do: apply_call(ExampleAPI, fname, args)
    end

    defp apply_call(module, fname, args) do
      case :erlang.apply(module, fname, args) do
        {:ok, any} -> any
        {:error, any} -> {:internal_error, any}
      end
    end
  end

  test "sane handler" do
    f = fn(x) ->
      {:reply, rep} = JSONRPC2.Server.Handler.handle(ExampleHandler, Poison, x)
      {:ok, decoded} = Poison.decode(rep)
      decoded
    end
    assert %{"result" => true} =
      f.(~s({"method": "is_even_N", "params": {"x": 26}, "id": 1, "jsonrpc": "2.0"}))
    assert %{"result" => false} =
      f.(~s({"method": "is_even_N", "params": {"x": 1}, "id": 1, "jsonrpc": "2.0"}))
    assert %{"error" => %{"code" => -32603}} =
      f.(~s({"method": "is_even_N", "params": {"x": -1}, "id": 1, "jsonrpc": "2.0"}))
    assert %{"result" => "method_not_found"} =
      f.(~s({"method": ":lists.filtermap", "params": {"x": -1}, "id": 1, "jsonrpc": "2.0"}))
  end

end

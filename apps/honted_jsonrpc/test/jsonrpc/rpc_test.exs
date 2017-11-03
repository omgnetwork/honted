defmodule HonteD.JSONRPC.Server.HandlerTest do
  use ExUnit.Case

  defmodule ExampleAPI do
    use HonteD.API.ExposeSpec

    @spec is_even_N(x :: integer) :: {:ok, boolean} | {:error, :badarg}
    def is_even_N(x) when x > 0 and is_integer(x) do
      {:ok, rem(x, 2) == 0}
    end
    def is_even_N(_) do
      {:error, :badarg}
    end

    @spec is_even_list(x :: [integer]) :: {:ok, boolean} | {:error, :badarg}
    def is_even_list(x) when is_list(x) do
     {:ok, Enum.all?(x, fn(x) -> rem(x, 2) == 0 end)}
    end
    def is_even_list(_) do
      {:error, :badarg}
    end

    @spec is_map_values_even(x :: %{:atom => integer}) :: {:ok, boolean} | {:error, :badarg}
    def is_map_values_even(x) when is_map(x) do
      checker = fn(x) -> rem(x, 2) == 0 end
      {:ok, Enum.all?(Map.values(x), checker)}
    end
    def is_map_values_even(_) do
      {:error, :badarg}
    end
  end

  # SUT (System Under Test):
  defmodule ExampleHandler do
    use JSONRPC2.Server.Handler

    @spec handle_request(method :: binary, params :: %{required(binary) => any}) :: any
    def handle_request(method, params) do
      with {:ok, fname, args} <- HonteD.API.RPCTranslate.to_fa(method, params, ExampleAPI.get_specs()),
           {:ok, result} <- apply_call(ExampleAPI, fname, args)
      do
        result
      else
        error -> throw error # JSONRPC requires to throw whatever fails, for proper handling of jsonrpc errors
      end
    end

    defp apply_call(module, fname, args) do
      case :erlang.apply(module, fname, args) do
        {:ok, any} -> {:ok, any}
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
    assert %{"result" => true} =
      f.(~s({"method": "is_even_list", "params": {"x": [2, 4]}, "id": 1, "jsonrpc": "2.0"}))
    assert %{"result" => false} =
      f.(~s({"method": "is_map_values_even", "params": {"x": {"a": 97, "b": 98}},
             "id": 1, "jsonrpc": "2.0"}))
    assert %{"result" => false} =
      f.(~s({"method": "is_even_N", "params": {"x": 1}, "id": 1, "jsonrpc": "2.0"}))
    assert %{"error" => %{"code" => -32603}} =
      f.(~s({"method": "is_even_N", "params": {"x": -1}, "id": 1, "jsonrpc": "2.0"}))
    assert %{"error" => %{"code" => -32601,
             "data" => %{"method" => ":lists.filtermap"},
             "message" => "Method not found"}} =
      f.(~s({"method": ":lists.filtermap", "params": {"x": -1}, "id": 1, "jsonrpc": "2.0"}))
  end

end

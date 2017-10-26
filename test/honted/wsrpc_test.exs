defmodule HonteD.WebsocketHandlerTest do
  use ExUnit.Case

  import HonteD.WebsocketHandler

  @timeout 100

  defmodule ExampleAPI do
    use ExposeSpec

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

    @spec event_me(subscriber :: pid) :: :ok
    def event_me(subscriber) do
      send(subscriber, {:committed, {1, :send, "asset", "amount", "src", "dest", "signature"}})
      :ok
    end
  end

  def call(x) do
    state = %{api: ExampleAPI}
    {:reply, {:text, rep}, nil, _} = websocket_handle({:text, x}, nil, state)
    {:ok, decoded} = Poison.decode(rep)
    decoded
  end

  def get_event(timeout \\ @timeout) do
    state = %{api: ExampleAPI}
    receive do
      msg ->
        {:reply, {:text, rep}, nil, _} = websocket_info(msg, nil, state);
        {:ok, decoded} = Poison.decode(rep)
        decoded
    after
      timeout -> throw :timeouted
    end
  end

  test "processes events" do
    assert %{"result" => "ok"} =
      call(~s({"method": "event_me", "params": {}, "type": "rq", "wsrpc": "1.0"}))
    assert %{"data" => %{"transaction" => %{"type" => "send"}}} =
      get_event()
  end

  test "sane handler" do
    assert %{"result" => true} =
      call(~s({"method": "is_even_N", "params": {"x": 26}, "type": "rq", "wsrpc": "1.0"}))
    assert %{"result" => true} =
      call(~s({"method": "is_even_list", "params": {"x": [2, 4]}, "type": "rq", "wsrpc": "1.0"}))
    assert %{"result" => false} =
      call(~s({"method": "is_map_values_even", "params": {"x": {"a": 97, "b": 98}},
             "type": "rq", "wsrpc": "1.0"}))
    assert %{"result" => false} =
      call(~s({"method": "is_even_N", "params": {"x": 1}, "type": "rq", "wsrpc": "1.0"}))
    assert %{"error" => %{"code" => -32603}} =
      call(~s({"method": "is_even_N", "params": {"x": -1}, "type": "rq", "wsrpc": "1.0"}))
    assert %{"error" => %{"code" => -32601}} =
      call(~s({"method": ":lists.filtermap", "params": {"x": -1}, "type": "rq", "wsrpc": "1.0"}))
  end

end

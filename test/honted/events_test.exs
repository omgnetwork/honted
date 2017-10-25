defmodule HonteD.EventerTest do
  @moduledoc """

  """
  use ExUnitFixtures
  use ExUnit.Case, async: false
  doctest HonteD

  import HonteD.API

  ## fixtures

  deffixture server do
    {:ok, pid} = HonteD.Eventer.start_link([])
    pid
  end

  ## helpers

  def address1(), do: "address1"
  def address2(), do: "address2"

  def event_send(receiver) do
    {nil, :send, nil, nil, nil, receiver, nil}
  end

  def event_block(number) do
    {:end_block, number}
  end

  def received(events, pid) do
    events = for e <- events, do: {:committed, e}
    assert {:ok, ^events} = Client.stop(pid)
  end

  defp join(pids) when is_list(pids) do
    for pid <- pids, do: join(pid)
  end
  defp join(pid) when is_pid(pid) do
    ref = Process.monitor(pid)
    receive do
      {:DOWN, ^ref, :process, ^pid, _} ->
        :ok
    end
  end

  defp join() do
    join(Process.get(:clients, []))
  end

  defp client(fun) do
    pid = spawn_link(fun)
    Process.put(:clients, [pid | Process.get(:clients, [])])
    pid
  end

  ## tests

  describe "Server and clients start and stop." do
    @tag fixtures: []
    test "Server can be registered.", %{} do
      {:ok, _server} = HonteD.Eventer.start_link([])
      assert {:ok, false} = send_filter_status?(self(), address1())
    end

    test "Inlined clients are useful" do
      msg = :stop
      pid = client(fn() -> assert_receive(^msg, 100) end)
      send(pid, msg)
      join()
    end
  end

  describe "One can register for events and receive it." do
    @tag fixtures: [:server]
    test "Subscribe, send event, receive event.", %{server: server} do
      e1 = event_send(address1())
      pid = client(fn() -> assert_receive({:committed, ^e1}, 200) end)
      send_filter_new(pid, address1())
      HonteD.Eventer.notify_committed(e1)
      join()
    end
  end

  describe "Subscribes and unsubscribes are handled." do
    @tag fixtures: [:server]
    test "Manual unsubscribe.", %{server: server} do
      pid = client(fn() -> assert_receive(:stop) end)
      assert {:ok, false} = send_filter_status?(pid, address1())
      send_filter_new(pid, address1())
      assert {:ok, true} = send_filter_status?(pid, address1())
      send_filter_drop(pid, address1())
      assert {:ok, false} = send_filter_status?(pid, address1())
      send(pid, :stop)
      join()
    end

    @tag fixtures: [:server]
    test "Automatic unsubscribe/cleanup.", %{server: server} do
      e1 = event_send(address1())
      pid1 = client(fn() -> assert_receive({:committed, ^e1}) end)
      pid2 = client(fn() ->
        assert_receive({:committed, ^e1})
        assert_receive({:committed, ^e1})
      end)
      send_filter_new(pid1, address1())
      send_filter_new(pid2, address1())
      assert {:ok, true} = send_filter_status?(pid1, address1())
      HonteD.Eventer.notify_committed(e1)
      join(pid1)
      assert {:ok, false} = send_filter_status?(pid1, address1())
      assert {:ok, true} = send_filter_status?(pid2, address1())
      HonteD.Eventer.notify_committed(e1)
      join()
    end
  end

  describe "Topics are handled." do
    @tag fixtures: [:server]
    test "Topics are distinct.", %{server: server}  do
      e1 = event_send(address1())
      pid1 = client(fn() -> assert_receive({:committed, ^e1}) end)
      pid2 = client(fn() -> refute_receive({:committed, ^e1}, 200) end)
      send_filter_new(pid1, address1())
      send_filter_new(pid2, address2())
      HonteD.Eventer.notify_committed(e1)
      join()
    end
  end

  describe "API does sanity checks on arguments." do
    @tag fixtures: [:server]
    test "Good topic.", %{server: server}  do
      assert :ok = send_filter_new(self(), address1())
    end
    @tag fixtures: [:server]
    test "Bad topic.", %{server: server}  do
      assert {:error, _} = send_filter_new(self(), 'this is not a binary')
    end
    @tag fixtures: [:server]
    test "Good sub.", %{server: server}  do
      assert :ok = send_filter_new(self(), address1())
    end
    @tag fixtures: [:server]
    test "Bad sub.", %{server: server}  do
      assert {:error, _} = send_filter_new(:registered_processes_will_not_be_handled,
                                           address1())
    end
  end

end

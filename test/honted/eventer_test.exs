defmodule HonteD.EventerTest do
  @moduledoc """
  Tests how one can use the API to subscribe to topics and receive event notifications
  
  Uses the applications instance of HonteD.Eventer
  """
  
  use ExUnit.Case, async: false

  import HonteD.API
  
  @timeout 100

  ## helpers

  def address1(), do: "address1"
  def address2(), do: "address2"

  def event_send(receiver) do
    {nil, :send, nil, nil, nil, receiver, nil}
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

  describe "Tests infrastructure sanity: server and test clients start and stop." do
    test "Inlined clients are useful" do
      msg = :stop
      pid = client(fn() -> assert_receive(^msg, @timeout) end)
      send(pid, msg)
      join()
    end
  end

  describe "One can register for events and receive it." do
    test "Subscribe, send event, receive event." do
      e1 = event_send(address1())
      pid = client(fn() -> assert_receive({:committed, ^e1}, @timeout) end)
      send_filter_new(pid, address1())
      HonteD.Eventer.notify_committed(e1)
      join()
    end
    
    test "empty subscriptions still work" do
      e1 = event_send(address1())
      _ = client(fn() -> refute_receive(_, @timeout) end)
      HonteD.Eventer.notify_committed(e1)
      join()
    end
    
    test "multiple subscriptions work once" do
      e1 = event_send(address1())
      pid = client(fn() -> 
        assert_receive({:committed, ^e1}, @timeout)
        refute_receive(_, @timeout)
      end)
      send_filter_new(pid, address1())
      send_filter_new(pid, address1())
      send_filter_new(pid, address1())
      HonteD.Eventer.notify_committed(e1)
      join()
    end
  end

  describe "Subscribes and unsubscribes are handled." do
    test "Manual unsubscribe." do
      pid = client(fn() -> refute_receive(_, @timeout) end)
      assert {:ok, false} = send_filter_status?(pid, address1())
      send_filter_new(pid, address1())
      assert {:ok, true} = send_filter_status?(pid, address1())
      send_filter_drop(pid, address1())
      assert {:ok, false} = send_filter_status?(pid, address1())
      
      # won't be notified
      e1 = event_send(address1())
      HonteD.Eventer.notify_committed(e1)
      join()
    end

    test "Automatic unsubscribe/cleanup." do
      e1 = event_send(address1())
      pid1 = client(fn() -> assert_receive({:committed, ^e1}, @timeout) end)
      pid2 = client(fn() ->
        assert_receive({:committed, ^e1}, @timeout)
        assert_receive({:committed, ^e1}, @timeout)
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
    test "Topics are distinct." do
      e1 = event_send(address1())
      pid1 = client(fn() -> assert_receive({:committed, ^e1}, @timeout) end)
      pid2 = client(fn() -> refute_receive({:committed, ^e1}, @timeout) end)
      send_filter_new(pid1, address1())
      send_filter_new(pid2, address2())
      HonteD.Eventer.notify_committed(e1)
      join()
    end
    
    test "similar send transactions don't match, but get accepted by Eventer" do
      # NOTE: behavior will require rethinking
      incorrect_e1 = {nil, :zend, nil, nil, nil, address1(), nil}
      pid1 = client(fn() -> refute_receive(_, @timeout) end)
      send_filter_new(pid1, address1())
      HonteD.Eventer.notify_committed(incorrect_e1)
      join()
    end
    
    test "outgoing send transaction don't match" do
      # NOTE: behavior will require rethinking
      e1 = {nil, :send, nil, nil, address1(), nil, nil}
      pid1 = client(fn() -> refute_receive(_, @timeout) end)
      send_filter_new(pid1, address1())
      HonteD.Eventer.notify_committed(e1)
      join()
    end
  end

  describe "API does sanity checks on arguments." do
    test "Good topic." do
      assert :ok = send_filter_new(self(), address1())
    end
    test "Bad topic." do
      assert {:error, _} = send_filter_new(self(), 'this is not a binary')
    end
    test "Good sub." do
      assert :ok = send_filter_new(self(), address1())
    end
    test "Bad sub." do
      assert {:error, _} = send_filter_new(:registered_processes_will_not_be_handled,
                                           address1())
    end
  end

end

defmodule HonteD.API.EventsTest do
  @moduledoc """
  Tests how one can use the API to subscribe to topics and receive event notifications

  Uses the application's instance of HonteD.Events.Eventer

  Uses the public HonteD.API for subscription/unsubscription and the public HonteD.Events api to emit events
  """

  import HonteD.Events

  use ExUnitFixtures
  use ExUnit.Case, async: true

  @timeout 100

  ## helpers

  deffixture server do
    {:ok, pid} = GenServer.start(HonteD.Events.Eventer, [], [])
    pid
  end

  deffixture named do
    {:ok, pid} = GenServer.start(HonteD.Events.Eventer, [], [named: HonteD.Events.Eventer])
    pid
  end

  def address1(), do: "address1"
  def address2(), do: "address2"

  def event_send(receiver, token \\ "asset") do
    # FIXME: how can I distantiate from the implementation details (like codec/encoding/creation) some more?
    # for now we use raw HonteD.Transaction structs, abandoned alternative is to go through encode/decode
    tx = %HonteD.Transaction.Send{nonce: 0, asset: token, amount: 1, from: "from_addr", to: receiver}
    {tx, receivable_for(tx)}
  end

  def event_sign_off(sender, send_receivables) do
    tx = %HonteD.Transaction.SignOff{nonce: 0, height: 1, hash: "hash", sender: sender}
    {tx, receivable_finalized(send_receivables)}
  end

  @doc """
  Prepared based on documentation of HonteD.Events.notify
  """
  def receivable_for(%HonteD.Transaction.Send{} = tx) do
    {:event, %{source: :filter, type: :committed, transaction: tx}}
  end

  def receivable_finalized(list) when is_list(list) do
    for event <- list, do: receivable_finalized(event)
  end
  def receivable_finalized({:event, recv = %{type: :committed}}) do
    {:event, %{recv | type: :finalized}}
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
    test "Assert_receive/2 is selective receive." do
      msg1 = :stop1
      msg2 = :stop2
      pid = client(fn() ->
        assert_receive(^msg2, @timeout)
        assert_receive(^msg1, @timeout)
      end)
      send(pid, msg1)
      send(pid, msg2)
      join()
    end
  end

  describe "One can register for events and receive it." do
    @tag fixtures: [:server]
    test "Subscribe, send event, receive event.", %{server: server}  do
      {e1, receivable1} = event_send(address1())
      pid = client(fn() -> assert_receive(^receivable1, @timeout) end)
      :ok = new_send_filter(server, pid, address1())
      notify(server, e1, [])
      join()
    end

    @tag fixtures: [:server]
    test "empty subscriptions still work", %{server: server} do
      {e1, _} = event_send(address1())
      _ = client(fn() -> refute_receive(_, @timeout) end)
      notify(server, e1, [])
      join()
    end

    @tag fixtures: [:server]
    test "multiple subscriptions work once", %{server: server} do
      {e1, receivable1} = event_send(address1())
      pid = client(fn() ->
        assert_receive(^receivable1, @timeout)
        refute_receive(_, @timeout)
      end)
      new_send_filter(server, pid, address1())
      new_send_filter(server, pid, address1())
      new_send_filter(server, pid, address1())
      notify(server, e1, [])
      join()
    end
  end

  describe "Both :committed and :finalized events are delivered." do
    @tag fixtures: [:server]
    test "Only :committed is delivered if sign_off is not issued.", %{server: server} do
      {e1, receivable} = event_send(address1())
      pid = client(fn() ->
        assert_receive(^receivable, @timeout)
        refute_receive(_, @timeout)
      end)
      new_send_filter(server, pid, address1())
      notify(server, e1, [])
      join()
    end

    @tag fixtures: [:server]
    test "Both are delivered if sign_off is issued.", %{server: server} do
      {e1, c1} = event_send(address1(), "asset1")
      {e2, c2} = event_send(address1(), "asset2")
      {e3, c3} = event_send(address1(), "asset1")
      {s1, [f1, f2, f3]} = event_sign_off(address1(), [c1, c2, c3])
      pid = client(fn() ->
        assert_receive(^c1, @timeout)
        assert_receive(^c2, @timeout)
        assert_receive(^c3, @timeout)
        assert_receive(^f1, @timeout)
        assert_receive(^f2, @timeout)
        assert_receive(^f3, @timeout)
      end)
      new_send_filter(server, pid, address1())
      notify(server, e1, [])
      notify(server, e2, [])
      notify(server, e3, [])
      notify(server, s1, ["asset1", "asset2"])
      join()
    end
  end

  describe "Subscribes and unsubscribes are handled." do
    @tag fixtures: [:server]
    test "Manual unsubscribe.", %{server: server} do
      pid = client(fn() -> refute_receive(_, @timeout) end)
      assert {:ok, false} = status_send_filter?(server, pid, address1())
      new_send_filter(server, pid, address1())
      assert {:ok, true} = status_send_filter?(server, pid, address1())
      :ok = drop_send_filter(server, pid, address1())
      assert {:ok, false} = status_send_filter?(server, pid, address1())

      # won't be notified
      {e1, _} = event_send(address1())
      notify(server, e1, [])
      join()
    end

    @tag fixtures: [:server]
    test "Automatic unsubscribe/cleanup.", %{server: server} do
      {e1, receivable1} = event_send(address1())
      pid1 = client(fn() -> assert_receive(^receivable1, @timeout) end)
      pid2 = client(fn() ->
        assert_receive(^receivable1, @timeout)
        assert_receive(^receivable1, @timeout)
      end)
      new_send_filter(server, pid1, address1())
      new_send_filter(server, pid2, address1())
      assert {:ok, true} = status_send_filter?(server, pid1, address1())
      notify(server, e1, [])
      join(pid1)
      assert {:ok, false} = status_send_filter?(server, pid1, address1())
      assert {:ok, true} = status_send_filter?(server, pid2, address1())
      notify(server, e1, [])
      join()
    end
  end

  describe "Topics are handled." do
    @tag fixtures: [:server]
    test "Topics are distinct.", %{server: server} do
      {e1, receivable1} = event_send(address1())
      pid1 = client(fn() -> assert_receive(^receivable1, @timeout) end)
      pid2 = client(fn() -> refute_receive(^receivable1, @timeout) end)
      new_send_filter(server, pid1, address1())
      new_send_filter(server, pid2, address2())
      notify(server, e1, [])
      join()
    end

    @tag fixtures: [:server]
    test "Similar send transactions don't match, but get accepted by Eventer.", %{server: server} do
      # NOTE: behavior will require rethinking
      unhandled_e = %HonteD.Transaction.Issue{nonce: 0, asset: "asset", amount: 1,
                                              dest: address1(), issuer: "issuer_addr"}
      pid1 = client(fn() -> refute_receive(_, @timeout) end)
      new_send_filter(server, pid1, address1())
      notify(server, unhandled_e, [])
      join()
    end

    @tag fixtures: [:server]
    test "Outgoing send transaction don't match.", %{server: server} do
      # NOTE: behavior will require rethinking
      e1 = %HonteD.Transaction.Send{nonce: 0, asset: "asset", amount: 1,
                                    from: address1(), to: "to_addr"}
      pid1 = client(fn() -> refute_receive(_, @timeout) end)
      new_send_filter(server, pid1, address1())
      notify(server, e1, [])
      join()
    end
  end

  describe "API does sanity checks on arguments." do
    @tag fixtures: [:server]
    test "Good topic.", %{server: server} do
      assert :ok = new_send_filter(server, self(), address1())
    end
    test "Bad topic." do
      assert {:error, _} = new_send_filter(self(), 'this is not a binary')
    end
    @tag fixtures: [:server]
    test "Good sub.", %{server: server} do
      assert :ok = new_send_filter(server, self(), address1())
    end
    test "Bad sub." do
      assert {:error, _} = new_send_filter(:registered_processes_will_not_be_handled,
                                           address1())
    end
  end

end

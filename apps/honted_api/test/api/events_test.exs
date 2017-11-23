defmodule HonteD.API.EventsTest do
  @moduledoc """
  Tests how one can use the API to subscribe to topics and receive event notifications

  Uses the application's instance of HonteD.API.Events.Eventer

  Uses the public HonteD.API for subscription/unsubscription and the public HonteD.API.Events api to emit events
  
  We test the logic of the events here
  """

  import HonteD.API.TestHelpers

  import HonteD.API.Events

  use ExUnitFixtures
  use ExUnit.Case, async: true
  import Mox

  @timeout 100

  ## helpers

  deffixture server do
    {:ok, pid} = GenServer.start(HonteD.API.Events.Eventer, [%{tendermint: HonteD.API.TestTendermint}], [])
    pid
  end

  defp mock_for_signoff(pid, n) do
    HonteD.API.TestTendermint
    |> expect(:block, n, &block_mock/2)
    |> expect(:client, n, fn() -> nil end)
    |> allow(self(), pid)
  end

  setup_all do
    start_supervised Mox.Server
    %{}
  end

  defp block_mock(_, height) do
    case height2hash(height) do
      nil -> nil
      hash -> {:ok, %{"block_meta" => %{"block_id" => %{"hash" => hash}}}}
    end
  end

  defp nsfilter(server, pid, topic) do
    case HonteD.API.Events.new_send_filter(server, pid, topic) do
      {:ok, %{new_filter: fid, start_height: height}} ->
        {:ok, fid, height}
      other ->
        other
    end
  end

  defp notify_woc(server, event) do
    notify_without_context(server, event)
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
      client(fn() ->
        {:ok, fid, 1} = nsfilter(server, self(), address1())
        {e1, receivable} = event_send(address1(), fid)
        notify_woc(server, e1)
        assert_receive(^receivable, @timeout)
      end)
      join()
    end

    @tag fixtures: [:server]
    test "empty subscriptions still work", %{server: server} do
      {e1, _} = event_send(address1(), nil)
      _ = client(fn() -> refute_receive(_, @timeout) end)
      notify_woc(server, e1)
      join()
    end
  end

  describe "Both :committed and :finalized events are delivered." do
    @tag fixtures: [:server]
    test "Only :committed is delivered if sign_off is not issued.", %{server: server} do
      client(fn() ->
        {:ok, fid, _} = nsfilter(server, self(), address1())
        {e1, receivable} = event_send(address1(), fid)
        notify_woc(server, e1)
        assert_receive(^receivable, @timeout)
        refute_receive(_, @timeout)
      end)
      join()
    end

    @tag fixtures: [:server]
    test "Both are delivered if sign_off is issued.", %{server: server} do
      mock_for_signoff(server, 1)
      client(fn() ->
        {:ok, fid, _} = nsfilter(server, self(), address1())
        {e1, com1} = event_send(address1(), fid, "asset1")
        {e2, com2} = event_send(address1(), fid, "asset2")
        {e3, com3} = event_send(address1(), fid, "asset1")
        {s1, [fin1, fin2, fin3]} = event_sign_off([com1, com2, com3])
        notify_woc(server, e1)
        notify_woc(server, e2)
        notify_woc(server, e3)
        notify(server, s1, ["asset1", "asset2"])
        assert_receive(^com1, @timeout)
        assert_receive(^com2, @timeout)
        assert_receive(^com3, @timeout)
        assert_receive(^fin1, @timeout)
        assert_receive(^fin2, @timeout)
        assert_receive(^fin3, @timeout)
      end)
      join()
    end

    @tag fixtures: [:server]
    test "Sign_off delivers tokens of the issuer who did the sign off", %{server: server} do
      mock_for_signoff(server, 1)
      client(fn() ->
        {:ok, fid, _} = nsfilter(server, self(), address1())
        {e1, com1} = event_send(address1(), fid, "asset1")
        {e2, com2} = event_send(address1(), fid, "asset2")
        {e3, com3} = event_send(address1(), fid, "asset3")
        {s1, [fin1, fin2]} = event_sign_off([com1, com2])
        notify_woc(server, e1)
        notify_woc(server, e2)
        notify_woc(server, e3)
        notify(server, s1, ["asset1", "asset2"])
        assert_receive(^com1, @timeout)
        assert_receive(^com2, @timeout)
        assert_receive(^com3, @timeout)
        assert_receive(^fin1, @timeout)
        assert_receive(^fin2, @timeout)
        refute_receive(_, @timeout)
      end)
      join()
    end

    @tag fixtures: [:server]
    test "Sign_off finalizes transactions only to certain height", %{server: server} do
      mock_for_signoff(server, 1)
      client(fn() ->
        {:ok, fid1, _} = nsfilter(server, self(), address1())
        {:ok, fid2, _} = nsfilter(server, self(), address2())
        {e1, com1} = event_send(address1(), fid1, "asset", 1)
        {e2, com2} = event_send(address2(), fid2, "asset", 2)
        {f1, [fin1, fin2]} = event_sign_off([com1, com2], 1)
        notify_woc(server, %HonteD.API.Events.NewBlock{height: 1})
        notify_woc(server, e1)
        notify_woc(server, %HonteD.API.Events.NewBlock{height: 2})
        notify_woc(server, e2)
        notify(server, f1, ["asset"])
        assert_receive(^fin1, @timeout)
        refute_receive(^fin2, @timeout)
      end)
      join()
    end

    @tag fixtures: [:server]
    test "Sign_off can be continued at later height", %{server: server} do
      mock_for_signoff(server, 2)
      client(fn() ->
        {:ok, fid1, _} = nsfilter(server, self(), address1())
        {:ok, fid2, _} = nsfilter(server, self(), address2())
        {e1, com1} = event_send(address1(), fid1, "asset", 1)
        {e2, com2} = event_send(address2(), fid2, "asset", 2)
        {f1, [fin1]} = event_sign_off([com1], 1)
        {f2, [fin2]} = event_sign_off([com2], 2)
        notify_woc(server, %HonteD.API.Events.NewBlock{height: 1})
        notify_woc(server, e1)
        notify_woc(server, %HonteD.API.Events.NewBlock{height: 2})
        notify_woc(server, e2)
        notify(server, f1, ["asset"])
        notify(server, f2, ["asset"])
        assert_receive(^fin1, @timeout)
        assert_receive(^fin2, @timeout)
      end)
      join()
    end

    @tag fixtures: [:server]
    test "Sign-off with bad hash is ignored", %{server: server} do
      mock_for_signoff(server, 1)
      client(fn() ->
        {:ok, fid, _} = nsfilter(server, self(), address1())
        {e1, com1} = event_send(address1(), fid)
        {f1, fin1} = event_sign_off_bad_hash(com1, 1)
        notify_woc(server, e1)
        notify_woc(server, %HonteD.API.Events.NewBlock{height: 1})
        notify(server, f1, ["asset"])
        assert_receive(^com1, @timeout)
        refute_receive(^fin1, @timeout)
      end)
      join()
    end
  end

  describe "Subscribes and unsubscribes are handled." do
    @tag fixtures: [:server]
    test "Manual unsubscribe.", %{server: server} do
      pid = client(fn() -> refute_receive(_, @timeout) end)
      assert {:error, :notfound} = status_filter(server, "not filter_id")
      {:ok, filter_id, _} = nsfilter(server, pid, address1())
      addr1 = address1()
      assert {:ok, [^addr1]} = status_filter(server, filter_id)
      :ok = drop_filter(server, filter_id)
      assert {:error, :notfound} = status_filter(server, filter_id)

      # won't be notified
      {e1, _} = event_send(address1(), nil)
      notify_woc(server, e1)
      join()
    end

    @tag fixtures: [:server]
    test "Automatic unsubscribe/cleanup.", %{server: server} do
      addr1 = address1()
      pid1 = client(fn() ->
        assert_receive(:stop1, @timeout)
      end)
      {:ok, filter_id1, _} = nsfilter(server, pid1, addr1)
      pid2 = client(fn() ->
        assert_receive(:stop2, @timeout)
      end)
      {:ok, filter_id2, _} = nsfilter(server, pid2, addr1)
      assert {:ok, [^addr1]} = status_filter(server, filter_id1)
      send(pid1, :stop1)
      join(pid1)
      assert {:error, :notfound} = status_filter(server, filter_id1)
      assert {:ok, [^addr1]} = status_filter(server, filter_id2)
      send(pid2, :stop2)
      join()
    end
  end

  describe "Topics are handled." do
    @tag fixtures: [:server]
    test "Topics are distinct.", %{server: server} do
      client(fn() ->
        {:ok, fid, _} = nsfilter(server, self(), address1())
        {e1, receivable1} = event_send(address1(), fid)
        notify_woc(server, e1)
        assert_receive(^receivable1, @timeout)
      end)
      client(fn() ->
        {:ok, fid, _} = nsfilter(server, self(), address2())
        {e1, receivable1} = event_send(address1(), fid)
        notify_woc(server, e1)
        refute_receive(^receivable1, @timeout)
      end)
      join()
    end

    @tag fixtures: [:server]
    test "Similar send transactions don't match, but get accepted by Eventer.", %{server: server} do
      # NOTE: behavior will require rethinking
      unhandled_e = %HonteD.Transaction.Issue{nonce: 0, asset: "asset", amount: 1,
                                              dest: address1(), issuer: "issuer_addr"}
      pid1 = client(fn() -> refute_receive(_, @timeout) end)
      nsfilter(server, pid1, address1())
      notify_woc(server, unhandled_e)
      join()
    end

    @tag fixtures: [:server]
    test "Outgoing send transaction don't match.", %{server: server} do
      # NOTE: behavior will require rethinking
      e1 = %HonteD.Transaction.Send{nonce: 0, asset: "asset", amount: 1,
                                    from: address1(), to: "to_addr"}
      pid1 = client(fn() -> refute_receive(_, @timeout) end)
      nsfilter(server, pid1, address1())
      notify_woc(server, e1)
      join()
    end
  end

  describe "API does sanity checks on arguments." do
    @tag fixtures: [:server]
    test "Good topic.", %{server: server} do
      assert {:ok, _, _} = nsfilter(server, self(), address1())
    end
    @tag fixtures: [:server]
    test "Bad topic.", %{server: server} do
      assert {:error, _} = nsfilter(server, self(), 'this is not a binary')
    end
    @tag fixtures: [:server]
    test "Good sub.", %{server: server} do
      assert {:ok, _, _} = nsfilter(server, self(), address1())
    end
    @tag fixtures: [:server]
    test "Bad sub.", %{server: server} do
      assert {:error, _} = nsfilter(server, :registered_processes_will_not_be_handled,
                                    address1())
    end
    @tag fixtures: [:server]
    test "Filter_id is a binary - status", %{server: server} do
      assert {:error, _} = status_filter(server, make_ref())
    end
    @tag fixtures: [:server]
    test "Filter_id is a binary - drop", %{server: server} do
      assert {:error, _} = drop_filter(server, make_ref())
    end
  end

end

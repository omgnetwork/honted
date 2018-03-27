#   Copyright 2018 OmiseGO Pte Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

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
      parent = self()
      height = 1
      {e1, {:event, receivable}} = event_send(address1(), 0, "asset", height)
      client(fn() ->
        {:ok, fid, _} = nsfilter(server, self(), address1())
        send(parent, :ready)

        assert_received_from_source(receivable, fid)
      end)
      receive do :ready -> :ok end
      notify_woc(server, %HonteD.API.Events.NewBlock{height: height})
      notify_woc(server, e1)
      join()
    end

    @tag fixtures: [:server]
    test "empty subscriptions still work", %{server: server} do
      {e1, _} = event_send(address1(), nil)
      client(fn() -> refute_receive(_, @timeout) end)
      notify_woc(server, e1)
      join()
    end
  end

  describe "Both :committed and :finalized events are delivered." do
    @tag fixtures: [:server]
    test "Only :committed is delivered if sign_off is not issued.", %{server: server} do
      parent = self()
      height = 1
      {e1, {:event, receivable}} = event_send(address1(), 0, "asset", height)
      client(fn() ->
        {:ok, fid, _} = nsfilter(server, self(), address1())
        send(parent, :ready)

        assert_received_from_source(receivable, fid)
        refute_receive(_, @timeout)
      end)
      receive do :ready -> :ok end
      notify_woc(server, %HonteD.API.Events.NewBlock{height: height})
      notify_woc(server, e1)
      join()
    end

    @tag fixtures: [:server]
    test "Both are delivered if sign_off is issued.", %{server: server} do
      mock_for_signoff(server, 1)
      parent = self()
      height = 1
      {e1, {:event, com1} = r1} = event_send(address1(), 0, "asset1", height)
      {e2, {:event, com2} = r2} = event_send(address1(), 0, "asset2", height)
      {e3, {:event, com3} = r3} = event_send(address1(), 0, "asset1", height)
      {s1, [{:event, fin1}, {:event, fin2}, {:event, fin3}]} = event_sign_off([r1, r2, r3])

      client(fn() ->
        {:ok, fid, _} = nsfilter(server, self(), address1())
        send(parent, :ready)

        assert_received_from_source(com1, fid)
        assert_received_from_source(com2, fid)
        assert_received_from_source(com3, fid)
        assert_received_from_source(fin1, fid)
        assert_received_from_source(fin2, fid)
        assert_received_from_source(fin3, fid)
      end)

      receive do :ready -> :ok end
      notify_woc(server, %HonteD.API.Events.NewBlock{height: height})
      notify_woc(server, e1)
      notify_woc(server, e2)
      notify_woc(server, e3)
      notify(server, s1, ["asset1", "asset2"])
      join()
    end

    @tag fixtures: [:server]
    test "Sign_off delivers tokens of the issuer who did the sign off", %{server: server} do
      mock_for_signoff(server, 1)
      parent = self()
      height = 1
      {e1, {:event, com1} = r1} = event_send(address1(), 0, "asset1", height)
      {e2, {:event, com2} = r2} = event_send(address1(), 0, "asset2", height)
      {e3, {:event, com3}} = event_send(address1(), 0, "asset3", height)
      {s1, [{:event, fin1}, {:event, fin2}]} = event_sign_off([r1, r2], height)

      client(fn() ->
        {:ok, fid, _} = nsfilter(server, self(), address1())
        send(parent, :ready)

        assert_received_from_source(com1, fid)
        assert_received_from_source(com2, fid)
        assert_received_from_source(com3, fid)
        assert_received_from_source(fin1, fid)
        assert_received_from_source(fin2, fid)
        refute_receive(_, @timeout)
      end)

      receive do :ready -> :ok end
      notify_woc(server, %HonteD.API.Events.NewBlock{height: height})
      notify_woc(server, e1)
      notify_woc(server, e2)
      notify_woc(server, e3)
      notify(server, s1, ["asset1", "asset2"])
      join()
    end

    @tag fixtures: [:server]
    test "Sign_off finalizes transactions only to certain height", %{server: server} do
      mock_for_signoff(server, 1)
      parent = self()
      {e1, com1} = event_send(address1(), 0, "asset", 1)
      {e2, com2} = event_send(address2(), 0, "asset", 2)
      {f1, [{:event, fin1}, {:event, fin2}]} = event_sign_off([com1, com2], 1)

      client(fn() ->
        {:ok, fid1, _} = nsfilter(server, self(), address1())
        {:ok, fid2, _} = nsfilter(server, self(), address2())
        send(parent, :ready)

        assert_received_from_source(fin1, fid1)

        not_expected = {:event, %{fin2 | source: fid2}}
        refute_receive(^not_expected, @timeout)
      end)

      receive do :ready -> :ok end
      notify_woc(server, %HonteD.API.Events.NewBlock{height: 1})
      notify_woc(server, e1)
      notify_woc(server, %HonteD.API.Events.NewBlock{height: 2})
      notify_woc(server, e2)
      notify(server, f1, ["asset"])
      join()
    end

    @tag fixtures: [:server]
    test "Sign_off can be continued at later height", %{server: server} do
      mock_for_signoff(server, 2)
      parent = self()
      {e1, com1} = event_send(address1(), 0, "asset", 1)
      {e2, com2} = event_send(address2(), 0, "asset", 2)
      {f1, [{:event, fin1}]} = event_sign_off([com1], 1)
      {f2, [{:event, fin2}]} = event_sign_off([com2], 2)

      client(fn() ->
        {:ok, fid1, _} = nsfilter(server, self(), address1())
        {:ok, fid2, _} = nsfilter(server, self(), address2())
        send(parent, :ready)

        assert_received_from_source(fin1, fid1)
        assert_received_from_source(fin2, fid2)
      end)

      receive do :ready -> :ok end
      notify_woc(server, %HonteD.API.Events.NewBlock{height: 1})
      notify_woc(server, e1)
      notify_woc(server, %HonteD.API.Events.NewBlock{height: 2})
      notify_woc(server, e2)
      notify(server, f1, ["asset"])
      notify(server, f2, ["asset"])
      join()
    end

    @tag fixtures: [:server]
    test "Sign-off with bad hash is ignored", %{server: server} do
      mock_for_signoff(server, 1)
      parent = self()
      height = 1
      {e1, {:event, com1} = r1} = event_send(address1(), 0, "asset", height)
      {f1, {:event, fin1}} = event_sign_off_bad_hash(r1, height)

      client(fn() ->
        {:ok, fid, _} = nsfilter(server, self(), address1())
        send(parent, :ready)

        assert_received_from_source(com1, fid)

        not_expected =  {:event, %{fin1 | source: fid}}
        refute_receive(^not_expected, @timeout)
      end)

      receive do :ready -> :ok end
      notify_woc(server, %HonteD.API.Events.NewBlock{height: height})
      notify_woc(server, e1)
      notify(server, f1, ["asset"])
      join()
    end
  end

  describe "Subscribes and unsubscribes are handled." do
    @tag fixtures: [:server]
    test "Manual unsubscribe.", %{server: server} do
      addr1 = address1()
      parent = self()
      pid = client(fn() ->
         {:ok, filter_id, _} = nsfilter(server, self(), addr1)
         send(parent, filter_id)
         receive do :drop_filter ->
           :ok = drop_filter(server, filter_id)
           send(parent, :filter_dropped)
         end
         refute_receive(_, @timeout)
       end)
      filter_id = receive do filter_id -> filter_id end
      assert {:ok, [^addr1]} = status_filter(server, filter_id)

      send(pid, :drop_filter)
      receive do :filter_dropped -> :ok end
      assert {:error, :notfound} = status_filter(server, filter_id)

      # won't be notified
      {e1, _} = event_send(addr1, nil)
      notify_woc(server, e1)
      join()
    end

    @tag fixtures: [:server]
    test "Automatic unsubscribe/cleanup.", %{server: server} do
      addr1 = address1()
      parent = self()
      pid1 = client(fn() ->
        {:ok, filter_id1, _} = nsfilter(server, self(), addr1)
        send(parent, {:child1, filter_id1})
        assert_receive(:stop1, @timeout)
      end)
      pid2 = client(fn() ->
        {:ok, filter_id2, _} = nsfilter(server, self(), addr1)
        send(parent, {:child2, filter_id2})
        assert_receive(:stop2, @timeout)
      end)

      filter_id1 = receive do {:child1, filter_id1} -> filter_id1 end
      notify_woc(server, %HonteD.API.Events.NewBlock{height: 0})
      assert {:ok, [^addr1]} = status_filter(server, filter_id1)
      send(pid1, :stop1)
      join(pid1)
      assert {:error, :notfound} = status_filter(server, filter_id1)

      filter_id2 = receive do {:child2, filter_id2} -> filter_id2 end
      notify_woc(server, %HonteD.API.Events.NewBlock{height: 1})
      assert {:ok, [^addr1]} = status_filter(server, filter_id2)
      send(pid2, :stop2)
      join()
    end
  end

  describe "Topics are handled." do
    @tag fixtures: [:server]
    test "Topics are distinct.", %{server: server} do
      parent = self()
      {e1, {:event, receivable1}} = event_send(address1(), 0, "asset", 1)
      client(fn() ->
        {:ok, fid, _} = nsfilter(server, self(), address1())
        send(parent, :ready)

        assert_received_from_source(receivable1, fid)
        refute_receive(_, @timeout)
      end)

      {e2, {:event, receivable2}} = event_send(address2(), 0, "asset", 2)
      client(fn() ->
        {:ok, fid, _} = nsfilter(server, self(), address2())
        send(parent, :ready)

        assert_received_from_source(receivable2, fid)
        refute_receive(_, @timeout)
      end)

      receive do :ready -> :ok end
      receive do :ready -> :ok end
      notify_woc(server, %HonteD.API.Events.NewBlock{height: 1})
      notify_woc(server, e1)
      notify_woc(server, %HonteD.API.Events.NewBlock{height: 2})
      notify_woc(server, e2)
      join()
    end

    @tag fixtures: [:server]
    test "Similar send transactions don't match, but get accepted by Eventer.", %{server: server} do
      # NOTE: behavior will require rethinking
      unhandled_e = %HonteD.Transaction.Issue{nonce: 0, asset: "asset", amount: 1,
                                              dest: address1(), issuer: "issuer_addr"}
      pid1 = client(fn() -> refute_receive(_, @timeout) end)
      {:ok, _, next_height} = nsfilter(server, pid1, address1())
      notify_woc(server, %HonteD.API.Events.NewBlock{height: next_height})
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

  defp assert_received_from_source(message, filter_id) do
    expected = {:event, %{message | source: filter_id}}
    assert_receive(^expected, @timeout)
  end

end

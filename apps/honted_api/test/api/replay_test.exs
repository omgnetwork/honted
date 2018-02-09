defmodule HonteD.API.ReplayTest do
  @moduledoc """
  Test replaying of transactions. This is separated from Events tests because of need to mock
  TendermintRPC API globally.
  """

  import HonteD.API.TestHelpers

  import HonteD.API.Events

  use ExUnitFixtures
  use ExUnit.Case, async: false
  import Mox

  deffixture server do
    {:ok, pid} = GenServer.start(HonteD.API.Events.Eventer, [%{tendermint: HonteD.API.TestTendermint}], [])
    pid
  end

  setup_all do
    start_supervised Mox.Server
    %{}
  end

  defp mock_block_transactions(_pid, n) do
    set_mox_global()
    HonteD.API.TestTendermint
    |> expect(:block, n, &block_transactions_mock/2)
    |> expect(:block_results, n, &block_results_transactions_mock/2)
    |> expect(:client, 1, fn() -> nil end)
    # using global mode
  end

  defp block_transactions_mock(_, height) do
    {:ok, %{
      "block" => %{
        "data" => %{"txs" => native_block(height)},
        "header" => %{"height" => height},
      }
    }}
  end

  defp block_results_transactions_mock(_, height) do
    {:ok, %{
      "results" => %{
        "DeliverTx" => native_block_results(height),
      },
    }}
  end

  defp native_block(1), do: [signed_send(1), ]
  defp native_block(2), do: []
  defp native_block(3), do: [signed_send(2), signed_send(3), ]
  defp native_block(4), do: [signed_send(4), ]
  defp native_block(n), do: [signed_send(n), ]

  defp native_block_results(1), do: [%{"code" => 0}, ]
  defp native_block_results(2), do: []
  defp native_block_results(3), do: [%{"code" => 0}, %{"code" => 0}, ]
  defp native_block_results(4), do: [%{"code" => 1}, ]
  defp native_block_results(_n), do: [%{"code" => 0}, ]

  defp signed_send(num) do
    {tx, _} = event_send(address1(), "nil", "asset", num)
    HonteD.TxCodec.encode(tx)
  end

  describe "Historical transactions can be replayed." do
    @tag fixtures: [:server]
    test "Replay does not deliver any extra events.", %{server: server} do
      mock_block_transactions(server, 2)
      client(fn() ->
        {:ok, %{history_filter: filter_id}} = new_send_filter_history(server, self(), address1(), 1, 2)
        {_, receivable1} = event_send(address1(), filter_id, "asset", 1)
        endmsg = {:event, HonteD.API.Events.Eventer.stream_end_msg(filter_id)}
        assert_receive(^receivable1, 1000)
        assert_receive(^endmsg)
        refute_receive(_)
      end)
      join()
    end

    @tag fixtures: [:server]
    test "Replay does not deliver failed transaction events.", %{server: server} do
      mock_block_transactions(server, 1)
      client(fn() ->
        {:ok, %{history_filter: filter_id}} = new_send_filter_history(server, self(), address1(), 4, 4)
        endmsg = {:event, HonteD.API.Events.Eventer.stream_end_msg(filter_id)}
        assert_receive(^endmsg)
        refute_receive(_)
      end)
      join()
    end

    @tag fixtures: [:server]
    test "Multiple events per block are processed.", %{server: server} do
      mock_block_transactions(server, 1)
      client(fn() ->
        {:ok, %{history_filter: filter_id}} =
          new_send_filter_history(server, self(), address1(), 3, 3)
        {_, r1} = event_send(address1(), filter_id, "asset", 3)
        {_, r2} = event_send(address1(), filter_id, "asset", 3)
        endmsg = {:event, HonteD.API.Events.Eventer.stream_end_msg(filter_id)}
        assert_receive(^r1)
        assert_receive(^r2)
        assert_receive(^endmsg)
        refute_receive(_)
      end)
      join()
    end

    @tag fixtures: [:server]
    test "Event about end of the stream is always delivered.", %{server: server} do
      mock_block_transactions(server, 1)
      client(fn() ->
        {:ok, %{history_filter: filter_id}} =
          new_send_filter_history(server, self(), address1(), 100, 100)
        endmsg = {:event, HonteD.API.Events.Eventer.stream_end_msg(filter_id)}
        assert_receive(^endmsg)
      end)
      join()
    end
  end
end

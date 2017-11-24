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
    |> expect(:block_transactions, n, &block_transactions_mock/2)
    |> expect(:client, 1, fn() -> nil end)
    # using global mode
  end

  defp block_transactions_mock(_, height) do
    native(height)
  end

  defp native(1), do: [signed_send(1), ]
  defp native(2), do: []
  defp native(3), do: [signed_send(2), signed_send(3), ]

  defp signed_send(num) do
    {tx, _} = event_send(address1(), "nil", "asset", num)
    raw_tx = HonteD.TxCodec.encode(tx)
    {:ok, signature} = HonteD.Crypto.sign(raw_tx, "fake_sig")
    "#{raw_tx} #{signature}"
  end

  describe "Historical transactions can be replayed." do
    @tag fixtures: [:server]
    test "Ranged replay works.", %{server: server} do
      mock_block_transactions(server, 2)
      client(fn() ->
        {:ok, %{history_filter: filter_id}} = new_send_filter_history(server, self(), address1(), 1, 2)
        {_, receivable1} = event_send(address1(), filter_id, "asset", 1)
        assert_receive(^receivable1, 1000)
        refute_receive(_)
      end)
      join()
    end
  end
end

defmodule HonteD.API.Events.Replay do
  @moduledoc """
  Gets historical transactions from Tendermint, filters them and sends them to subscriber.
  Only :committed transactions are replayed. To check if transaction was finalized
  subscriber should use `HonteD.API.tx`.
  """

  require Logger
  alias HonteD.API.Events.Eventer, as: Eventer

  defp iterate_block(block, ad_hoc_subscription, ad_hoc_filters) do
    height = get_in(block, ["block", "header", "height"])

    block
    |> get_in(["block", "data", "txs"])
    |> Enum.map(&HonteD.TxCodec.decode!/1)
    |> Enum.map(&(&1.raw_tx))
    |> Enum.map(&(Eventer.do_notify(:committed, &1, height, ad_hoc_subscription, ad_hoc_filters)))
    |> Enum.map(fn :ok -> true end)
  end

  defp get_block(tendermint, client, height) do
    {:ok, block} = tendermint.block(client, height)
    block
  end

  def spawn(filter_id, tendermint, block_range, topics, pid) do
    client = tendermint.client()
    ad_hoc_subscription = BiMultiMap.new([{topics, pid}])
    ad_hoc_filters = BiMultiMap.new([{filter_id, {topics, pid}}])
    {:ok, _} = Task.start(fn() ->
      try do
        block_range
        |> Stream.map(fn height -> get_block(tendermint, client, height) end)
        |> Enum.map(fn block -> iterate_block(block, ad_hoc_subscription, ad_hoc_filters) end)
      after
        msg = Eventer.stream_end_msg(filter_id)
        send(pid, {:event, msg})
      end
    end)
  end

end

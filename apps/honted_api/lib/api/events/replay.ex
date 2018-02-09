defmodule HonteD.API.Events.Replay do
  @moduledoc """
  Gets historical transactions from Tendermint, filters them and sends them to subscriber.
  Only :committed transactions are replayed. To check if transaction was finalized
  subscriber should use `HonteD.API.tx`.
  """

  require Logger
  alias HonteD.API.Events.Eventer, as: Eventer

  defp iterate_block({block, results}, ad_hoc_subscription, ad_hoc_filters) do
    height = get_in(block, ["block", "header", "height"])

    block
    |> get_in(["block", "data", "txs"])
    |> Stream.map(&HonteD.TxCodec.decode!/1)
    |> Stream.map(&(&1.raw_tx))
    |> drop_failed_txs(results)
    |> Stream.map(fn tx -> Eventer.do_notify(:committed, tx, height, ad_hoc_subscription, ad_hoc_filters) end)
    |> Enum.each(fn :ok -> true end)
  end

  defp get_block_with_results!(tendermint, client, height) do
    {:ok, block} = tendermint.block(client, height)
    {:ok, results} = tendermint.block_results(client, height)
    {block, results}
  end

  # uses the block_results from tendermint rpc to only act on successfully executed transactions
  defp drop_failed_txs(txs, results) do
    txs
    |> Stream.zip(get_in(results, ["results", "DeliverTx"]))
    |> Stream.filter(fn {_tx, result} -> result["code"] == 0 end)
    |> Stream.map(fn {tx, _result} -> tx end)
  end

  def spawn(filter_id, tendermint, block_range, topics, pid) do
    client = tendermint.client()
    ad_hoc_subscription = BiMultiMap.new([{topics, pid}])
    ad_hoc_filters = BiMultiMap.new([{filter_id, {topics, pid}}])
    {:ok, _} = Task.start(fn() ->
      try do
        block_range
        |> Stream.map(fn height -> get_block_with_results!(tendermint, client, height) end)
        |> Enum.map(fn {block, results} -> iterate_block({block, results}, ad_hoc_subscription, ad_hoc_filters) end)
      after
        msg = Eventer.stream_end_msg(filter_id)
        send(pid, {:event, msg})
      end
    end)
  end

end

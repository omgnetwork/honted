defmodule HonteD.API.Events.Replay do
  @moduledoc """
  Gets historical transactions from Tendermint, filters them and sends them to subscriber.
  Only :committed transactions are replayed. To check if transaction was finalized
  subscriber should use `HonteD.API.tx`.
  """

  require Logger
  alias HonteD.API.Events.Eventer, as: Eventer

  def spawn(filter_id, tendermint, first, last, topics, pid) do
    client = tendermint.client()
    ad_hoc_subscription = BiMultiMap.new([{topics, pid}])
    ad_hoc_filters = BiMultiMap.new([{filter_id, {topics, pid}}])
  {:ok, _} = Task.start(fn() ->
      iterate = fn() ->
        for height <- first..last do
          tendermint.block_transactions(client, height)
          |> Enum.map(&HonteD.TxCodec.decode!/1)
          |> Enum.map(&(Map.get(&1, :raw_tx)))
          |> Enum.map(&(Eventer.do_notify(:committed, &1, height, ad_hoc_subscription, ad_hoc_filters)))
          |> Enum.map(fn :ok -> true end)
        end
      end
      # FIXME: this needs refactoring
      try do
        iterate.()
      after
        msg = Eventer.stream_end_msg(filter_id)
        send(pid, {:event, msg})
      end
    end)
  end

end

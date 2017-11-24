defmodule HonteD.API.Events.Replay do
  @moduledoc """
  Gets historical transactions from Tendermint and pushes them into Eventer
  """

  require Logger
  alias HonteD.API.Events.Eventer, as: Eventer

  def spawn(filter_id, tendermint, first, last, topics, pid) do
    client = tendermint.client()
    ad_hoc_subscription = BiMultiMap.new([{topics, pid}])
    ad_hoc_filters = BiMultiMap.new([{filter_id, {topics, pid}}])
    {:ok, _} = Task.start(fn() ->
      for height <- first..last do
        {:ok, txs} = tendermint.block_transactions(client, height)
        txs
        |> Enum.map(&HonteD.TxCodec.decode!/1)
        |> Enum.map(&(Map.get(&1, :raw_tx)))
        |> Enum.map(&(Eventer.do_notify(:committed, &1, height, ad_hoc_subscription, ad_hoc_filters)))
        |> Enum.map(fn :ok -> true end)
      end
    end)
  end

end

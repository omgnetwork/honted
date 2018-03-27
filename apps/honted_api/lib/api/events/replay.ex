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

defmodule HonteD.API.Events.Replay do
  @moduledoc """
  Gets historical transactions from Tendermint, filters them and sends them to subscriber.
  Only :committed transactions are replayed. To check if transaction was finalized
  subscriber should use `HonteD.API.tx`.
  """

  require Logger
  alias HonteD.API.Events.Eventer, as: Eventer

  defp iterate_block({block, results}, subscription, filters) do
    height = get_in(block, ["block", "header", "height"])

    block
    |> get_in(["block", "data", "txs"])
    |> Stream.map(&HonteD.TxCodec.decode!/1)
    |> drop_failed_txs(results)
    |> Stream.map(&(Eventer.do_notify(:committed, &1, height, subscription, filters)))
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

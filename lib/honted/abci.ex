defmodule HonteD.ABCI do
  @moduledoc """
  Entrypoint for all calls from Tendermint targeting the ABCI - abstract blockchain interface

  This manages the `honted` ABCI app's state.
  ABCI calls originate from :abci_server (Erlang)
  """
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def handle_request(request) do
    GenServer.call(__MODULE__, request)
  end

  def init(:ok) do
    {:ok, HonteD.State.empty()}
  end

  def handle_call({:RequestInfo}, _from, state) do
    {:reply, {
      :ResponseInfo,
      'arbitrary information',
      'version info',
      0,  # latest block height - always start from zero
      '', # latest app hash - because we start from zero this _must_ be empty charlist
    }, state}
  end

  def handle_call({:RequestEndBlock, _block_number}, _from, state) do
    {:reply, {:ResponseEndBlock, []}, state}
  end

  def handle_call({:RequestBeginBlock, _hash, {:Header, _chain_id, height, _timestamp, _some_zero_value,
 _block_id, _something1, _something2, _something3, app_hash}}, _from, state) do

    # consistency check after genesis block is required
    if height > 1 do
      ^app_hash = HonteD.State.hash(state)
    end

    {:reply, {:ResponseBeginBlock}, state}
  end

  def handle_call({:RequestCommit}, _from, state) do
    {:reply, {
      :ResponseCommit,
      0,
      (state |> HonteD.State.hash |> to_charlist),
      'commit log: yo!'
    }, state}
  end

  def handle_call({:RequestCheckTx, tx}, _from, state) do
    case HonteD.TxCodec.decode(tx) do
      {:ok, decoded} -> case HonteD.State.exec(state, decoded) do
        # no change to state! we don't allow to build upon uncommited transactions
        {:ok, _} ->
          {:reply, {:ResponseCheckTx, 0, '', ''}, state}
        {:error, _} ->  # FIXME: redesign the return values everywhere
          {:reply, {:ResponseCheckTx, 1, '', to_charlist("error")}, state}
      end
      {:error, error} -> {:reply, {:ResponseCheckTx, 1, '', to_charlist(error)}, state}
    end
  end

  def handle_call({:RequestDeliverTx, tx}, _from, state) do
    {:ok, decoded} = IO.inspect HonteD.TxCodec.decode(tx)
    {:ok, state} = HonteD.State.exec(state, decoded)
    {:reply, {:ResponseDeliverTx, 0, '', ''}, IO.inspect state}
  end

  @doc """
  Not implemented: we don't yet support tendermint's standard queries to /store
  """
  def handle_call({:RequestQuery, _data, '/store', 0, :false}, _from, state) do
    {:reply, {:ResponseQuery, 1, 0, '', '', 'no proof', 0, 'query to /store not implemented'}, state}
  end

  @doc """
  Specific query for nonces which provides zero for unknown senders
  """
  def handle_call({:RequestQuery, "", '/nonces' ++ address, 0, :false}, _from, state) do
    key = "nonces" <> to_string(address)
    value = Map.get(state, key, 0)
    {:reply, {:ResponseQuery, 0, 0, to_charlist(key), to_charlist(value), 'no proof', 0, ''}, state}
  end

  @doc """
  Generic raw query for any key in state.
  
  TODO: interface querying the state out, so that state remains implementation detail
  """
  def handle_call({:RequestQuery, "", path, 0, :false}, _from, state) do
    "/" <> key = to_string(path)
    # FIXME: Error code value of 1 is arbitrary. Check Tendermint docs for appropriate value.
    {code, value} = case state[key] do
      nil -> {1, ""}
      value -> {0, value}
    end
    {:reply, {:ResponseQuery, code, 0, to_charlist(key), to_charlist(value), 'no proof', 0, ''}, state}
  end

  @doc """
  Dissallow queries with non-empty-string data field for now
  """
  def handle_call({:RequestQuery, _data, _path, _height, _prove}, _from, state) do
    {:reply, {:ResponseQuery, 1, 0, '', '', 'no proof', 0, 'unrecognized query'}, state}
  end

  # FIXME: all-matching clause to keep tendermint from complaining, remove!
  def handle_call(request, from, state) do
    IO.puts "UNHANDLED"
    IO.inspect request
    IO.inspect from
    {:reply, {}, state}
  end
end

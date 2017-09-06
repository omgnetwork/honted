defmodule HonteD do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def handle_request(request) do
    GenServer.call(__MODULE__, request)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:RequestInfo}, _from, state) do
    {:reply, {:ResponseInfo, '','',0,''}, state}
  end

  def handle_call({:RequestEndBlock, _block_number}, _from, state) do
    {:reply, {:ResponseEndBlock, []}, state}
  end

  def handle_call({:RequestBeginBlock, _hash, _header}, _from, state) do
    {:reply, {:ResponseBeginBlock}, state}
  end

  def handle_call({:RequestCommit}, _from, state) do
    {:reply, {:ResponseCommit, 0, '3D8D0F663CD3C8093532EEF65958A8C243313D82', 'yo!'}, state}
  end

  def handle_call({:RequestCheckTx, tx}, _from, state) do
    {:ok, decoded} = IO.inspect HonteD.TxDecoder.decode(tx)
    case HonteD.State.exec(state, decoded) do
      # FIXME: no change to state!!! is this right?
      {:ok, _} ->
        {:reply, {:ResponseCheckTx, 0, 'answer check tx', 'log check tx'}, state}
      {:error, _} ->  # FIXME: redesign the return values everywhere
        {:reply, {:ResponseCheckTx, 1, 'answer check tx', to_charlist("error")}, state}
    end
  end

  def handle_call({:RequestDeliverTx, tx}, _from, state) do
    {:ok, decoded} = IO.inspect HonteD.TxDecoder.decode(tx)
    {:ok, state} = HonteD.State.exec(state, decoded)
    {:reply, {:ResponseDeliverTx, 0, 'answer deliver tx', 'log deliver tx'}, IO.inspect state}
  end

  def handle_call({:RequestQuery, _data, _path, height, _prove}, _from, state) do
    {:reply, {:ResponseQuery, 0, 0, 'key', 'value', 'proof', height, 'query log'}, state}
  end

  def handle_call(_request, _from, state) do
    {:reply, {}, state}
  end

  def handle_cast(_request, state) do
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end

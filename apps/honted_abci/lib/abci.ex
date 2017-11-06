defmodule HonteD.ABCI do
  @moduledoc """
  Entrypoint for all calls from Tendermint targeting the ABCI - abstract blockchain interface

  This manages the `honted` ABCI app's state.
  ABCI calls originate from :abci_server (Erlang)
  """
  require Logger
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def handle_request(request) do
    GenServer.call(__MODULE__, request)
  end

  def init(:ok) do
    {:ok, HonteD.ABCI.State.empty()}
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
      ^app_hash = HonteD.ABCI.State.hash(state)
    end

    {:reply, {:ResponseBeginBlock}, state}
  end

  def handle_call({:RequestCommit}, _from, state) do
    {:reply, {
      :ResponseCommit,
      0,
      (state |> HonteD.ABCI.State.hash |> to_charlist),
      'commit log: yo!'
    }, state}
  end

  def handle_call({:RequestCheckTx, tx}, _from, state) do
    with {:ok, decoded} <- HonteD.TxCodec.decode(tx),
         {:ok, _} <- generic_handle_tx(state, decoded)
    do
      # no change to state! we don't allow to build upon uncommited transactions
      {:reply, {:ResponseCheckTx, 0, '', ''}, state}
    else
      {:error, error} -> {:reply, {:ResponseCheckTx, 1, '', to_charlist(error)}, state}
    end
  end

  def handle_call({:RequestDeliverTx, tx}, _from, state) do
    with {:ok, decoded} <- HonteD.TxCodec.decode(tx),
         {:ok, state} <- generic_handle_tx(state, decoded)
    do
      HonteD.Events.notify_committed(decoded.raw_tx)
      {:reply, {:ResponseDeliverTx, 0, '', ''}, state}
    else
      {:error, error} -> {:reply, {:ResponseDeliverTx, 1, '', to_charlist(error)}, state}
    end
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
    {:reply, {:ResponseQuery, 0, 0, to_charlist(key), encode_query_response(value), 'no proof', 0, ''}, state}
  end
  
  @doc """
  Specialized query for issued tokens for an issuer
  """
  def handle_call({:RequestQuery, "", '/issuers' ++ address, 0, :false}, _from, state) do
    key = "issuers" <> to_string(address)
    "/" <> str_address = to_string(address)
    case lookup(state, key) do
      {0, value, log} ->
        {:reply, {:ResponseQuery, 0, 0, to_charlist(key), value 
                                                          |> scan_potential_issued(state, str_address) 
                                                          |> encode_query_response,
                  'no proof', 0, log}, state}
      {code, value, log} ->
        # problems - forward raw
        {:reply, {:ResponseQuery, code, 0, to_charlist(key), to_charlist(value), 'no proof', 0, log}, state}
    end
  end

  @doc """
  Generic raw query for any key in state.
  
  TODO: interface querying the state out, so that state remains implementation detail
  """
  def handle_call({:RequestQuery, "", path, 0, :false}, _from, state) do
    "/" <> key = to_string(path)
    {code, value, log} = lookup(state, key)
    {:reply, {:ResponseQuery, code, 0, to_charlist(key), encode_query_response(value), 'no proof', 0, log}, state}
  end

  @doc """
  Dissallow queries with non-empty-string data field for now
  """
  def handle_call({:RequestQuery, _data, _path, _height, _prove}, _from, state) do
    {:reply, {:ResponseQuery, 1, 0, '', '', 'no proof', 0, 'unrecognized query'}, state}
  end

  # FIXME: all-matching clause to keep tendermint from complaining, remove!
  def handle_call(request, from, state) do
    Logger.warn("Warning: unhandled call from tendermint request: #{inspect request} from #{inspect from}")
    {:reply, {}, state}
  end
  
  ### END GenServer
  
  defp encode_query_response(object) do
    object
    |> Poison.encode!
    |> to_charlist
  end
  
  defp generic_handle_tx(state, tx) do
    with :ok <- HonteD.Transaction.Validation.valid_signed?(tx),
         do: HonteD.ABCI.State.exec(state, tx)
  end
  
  defp scan_potential_issued(unfiltered_tokens, state, issuer) do
    unfiltered_tokens
    |> Enum.filter(fn token_addr -> state["tokens/#{token_addr}/issuer"] == issuer end)
  end
  
  defp lookup(state, key) do
    # FIXME: Error code value of 1 is arbitrary. Check Tendermint docs for appropriate value.
    case state[key] do
      nil -> {1, "", 'not_found'}
      value -> {0, value, ''}
    end
  end
end

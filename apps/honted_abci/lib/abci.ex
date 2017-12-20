defmodule HonteD.ABCI do
  @moduledoc """
  Entrypoint for all calls from Tendermint targeting the ABCI - abstract blockchain interface

  This manages the `honted` ABCI app's state.
  ABCI calls originate from :abci_server (Erlang)
  """
  require Logger
  use GenServer

  alias HonteD.ABCI.State, as: State

  @doc """
  Tracks state which is controlled by consensus and also tracks local (mempool related, transient) state.
  Local state is being overwritten by consensus state on every commit.
  """
  defstruct [consensus_state: State.empty(),
             local_state: State.empty(),
            ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def handle_request(request) do
    GenServer.call(__MODULE__, request)
  end

  def init(:ok) do
    {:ok, %__MODULE__{}}
  end

  def handle_call({:RequestInfo}, _from, abci_app) do
    {:reply, {
      :ResponseInfo,
      'arbitrary information',
      'version info',
      0,  # latest block height - always start from zero
      '', # latest app hash - because we start from zero this _must_ be empty charlist
    }, abci_app}
  end

  def handle_call({:RequestEndBlock, _block_number}, _from, abci_app) do
    {:reply, {:ResponseEndBlock, []}, abci_app}
  end

  def handle_call({:RequestBeginBlock, _hash, {:Header, _chain_id, height, _timestamp, _some_zero_value,
 _block_id, _something1, _something2, _something3, _app_hash}}, _from, abci_app) do
    HonteD.ABCI.Events.notify(abci_app.consensus_state, %HonteD.API.Events.NewBlock{height: height})
    {:reply, {:ResponseBeginBlock}, abci_app}
  end

  def handle_call({:RequestCommit}, _from, abci_app) do
    {:reply, {
      :ResponseCommit,
      code(:ok),
      (abci_app.consensus_state |> State.hash |> to_charlist),
      'commit log: yo!'
    }, %{abci_app | local_state: abci_app.consensus_state}}
  end

  def handle_call({:RequestCheckTx, tx}, _from, abci_app) do
    with {:ok, decoded} <- HonteD.TxCodec.decode(tx),
         {:ok, new_local_state} <- generic_handle_tx(abci_app.local_state, decoded)
    do
      # no change to state! we don't allow to build upon uncommited transactions
      {:reply, {:ResponseCheckTx, code(:ok), '', ''}, %{abci_app | local_state: new_local_state}}
    else
      {:error, error} ->
        {:reply, {:ResponseCheckTx, code(error), '', to_charlist(error)}, abci_app}
    end
  end

  def handle_call({:RequestDeliverTx, tx}, _from, abci_app) do
    # NOTE: yes, we want to crash on invalid transactions, lol
    # there's a chore to fix that
    {:ok, decoded} = HonteD.TxCodec.decode(tx)
    {:ok, new_consensus_state} = generic_handle_tx(abci_app.consensus_state, decoded)
    HonteD.ABCI.Events.notify(new_consensus_state, decoded.raw_tx)
    {:reply, {:ResponseDeliverTx, code(:ok), '', ''}, %{abci_app | consensus_state: new_consensus_state}}
  end

  @doc """
  Not implemented: we don't yet support tendermint's standard queries to /store
  """
  def handle_call({:RequestQuery, _data, '/store', 0, :false}, _from, abci_app) do
    {:reply, {:ResponseQuery, code(:not_implemented), 0, '', '', 'no proof', 0,
              'query to /store not implemented'}, abci_app}
  end

  @doc """
  Specific query for nonces which provides zero for unknown senders
  """
  def handle_call({:RequestQuery, "", '/nonces' ++ address, 0, :false}, _from, abci_app) do
    key = "nonces" <> to_string(address)
    value = Map.get(abci_app.consensus_state, key, 0)
    {:reply, {:ResponseQuery, code(:ok), 0, to_charlist(key), encode_query_response(value),
              'no proof', 0, ''}, abci_app}
  end

  @doc """
  Specialized query for issued tokens for an issuer
  """
  def handle_call({:RequestQuery, "", '/issuers/' ++ address, 0, :false}, _from, abci_app) do
    key = "issuers/" <> to_string(address)
    {code, value, log} = handle_get(State.issued_tokens(abci_app.consensus_state, address))
    return = {:ResponseQuery, code, 0, to_charlist(key),
              encode_query_response(value), 'no proof', 0, log}
    {:reply, return, abci_app}
  end

  @doc """
  Generic raw query for any key in state.

  TODO: interface querying the state out, so that state remains implementation detail
  """
  def handle_call({:RequestQuery, "", path, 0, :false}, _from, abci_app) do
    "/" <> key = to_string(path)
    {code, value, log} = lookup(abci_app.consensus_state, key)
    {:reply, {:ResponseQuery, code, 0, to_charlist(key), encode_query_response(value), 'no proof', 0, log},
     abci_app}
  end

  @doc """
  Dissallow queries with non-empty-string data field for now
  """
  def handle_call({:RequestQuery, _data, _path, _height, _prove}, _from, abci_app) do
    {:reply, {:ResponseQuery, code(:not_implemented), 0, '', '', 'no proof', 0, 'unrecognized query'}, abci_app}
  end

  def handle_call({:RequestInitChain, [{:Validator, _somebytes, _someint}]} = request, from, abci_app) do
    _ = Logger.warn("Warning: unhandled call from tendermint request: #{inspect request} from #{inspect from}")
    {:reply, {}, abci_app}
  end

  ### END GenServer

  defp encode_query_response(object) do
    object
    |> Poison.encode!
    |> to_charlist
  end

  defp generic_handle_tx(state, tx) do
    with :ok <- HonteD.Transaction.Validation.valid_signed?(tx),
         do: State.exec(state, tx)
  end

  defp lookup(state, key) do
    state |> State.get(key) |> handle_get
  end

  defp handle_get({:ok, value}), do: {code(:ok), value, ''}
  defp handle_get(nil), do: {code(:not_found), "", 'not_found'}

  # NOTE: Define our own mapping from our error atoms to codes in range [1,...].
  #       See https://github.com/tendermint/abci/pull/145 and related.
  defp code(:ok), do: 0
  defp code(_), do: 1

end

defmodule HonteD.ABCI do
  @moduledoc """
  Entrypoint for all calls from Tendermint targeting the ABCI - abstract blockchain interface

  This manages the `honted` ABCI app's state.
  ABCI calls originate from :abci_server (Erlang)
  """
  require Logger
  use GenServer
  import HonteD.ABCI.Records

  alias HonteD.Staking
  alias HonteD.ABCI.State
  alias HonteD.Transaction
  alias HonteD.Validator

  @doc """
  Tracks state which is controlled by consensus and also tracks local (mempool related, transient) state.
  Local state is being overwritten by consensus state on every commit.
  """
  defstruct [consensus_state: State.initial(),
             local_state: State.initial(),
             staking_state: nil,
             initial_validators: nil
            ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def handle_request(request) do
    GenServer.call(__MODULE__, request)
  end

  def init(:ok, staking_state) do
    abci_app = %{%__MODULE__{} | staking_state: staking_state}
    {:ok, abci_app}
  end

  # FIXME: double check if right - we absolutely need to override the default `init` - possibly with an error
  def init(:ok) do
    init(:ok, nil)
  end

  def handle_call(request_info(version: _), _from, %HonteD.ABCI{} = abci_app) do
    reply = response_info(last_block_height: 0)
    {:reply, reply, abci_app}
  end

  def handle_call(request_end_block(height: _height), _from,
  %HonteD.ABCI{consensus_state: consensus_state, staking_state: staking_state,
               initial_validators: initial_validators} = abci_app) do
    diffs = validators_diff(consensus_state, staking_state, initial_validators)
    consensus_state = move_to_next_epoch_if_epoch_changed(consensus_state)
    {:reply, response_end_block(diffs: diffs), %{abci_app | consensus_state: consensus_state}}
  end

  def handle_call(request_begin_block(header: header(height: height)), _from,
  %HonteD.ABCI{consensus_state: consensus_state} = abci_app) do
    HonteD.ABCI.Events.notify(consensus_state, %HonteD.API.Events.NewBlock{height: height})
    {:reply, response_begin_block(), abci_app}
  end

  def handle_call(request_commit(), _from, %HonteD.ABCI{consensus_state: consensus_state} = abci_app) do
    hash = (consensus_state |> State.hash |> to_charlist)
    reply = response_commit(code: code(:ok), data: hash, log: 'commit log: yo!')
    {:reply, reply, %{abci_app | local_state: consensus_state}}
  end

  def handle_call(request_check_tx(tx: tx), _from, %HonteD.ABCI{} = abci_app) do
    with {:ok, decoded} <- HonteD.TxCodec.decode(tx),
         {:ok, new_local_state} <- handle_tx(abci_app, decoded, &(&1.local_state))
    do
      # no change to state! we don't allow to build upon uncommited transactions
      {:reply, response_check_tx(code: code(:ok)), %{abci_app | local_state: new_local_state}}
    else
      {:error, error} ->
        {:reply, response_check_tx(code: code(error), log: to_charlist(error)), abci_app}
    end
  end

  def handle_call(request_deliver_tx(tx: tx), _from, %HonteD.ABCI{} = abci_app) do
    # NOTE: yes, we want to crash on invalid transactions, lol
    # there's a chore to fix that
    {:ok, decoded} = HonteD.TxCodec.decode(tx)
    {:ok, new_consensus_state} = handle_tx(abci_app, decoded, &(&1.consensus_state))
    HonteD.ABCI.Events.notify(new_consensus_state, decoded.raw_tx)
    {:reply, response_deliver_tx(code: code(:ok)), %{abci_app | consensus_state: new_consensus_state}}
  end

  @doc """
  Dissallow queries with non-empty-string data field for now
  """
  def handle_call(request_query(data: data), _from, %HonteD.ABCI{} = abci_app) when data != "" do
    reply = response_query(code: code(:not_implemented), proof: 'no proof', log: 'unrecognized query')
    {:reply, reply, abci_app}
  end

  @doc """
  Not implemented: we don't yet support tendermint's standard queries to /store
  """
  def handle_call(request_query(path: '/store'), _from, %HonteD.ABCI{} = abci_app) do
    reply = response_query(code: code(:not_implemented), proof: 'no proof',
      log: 'query to /store not implemented')
    {:reply, reply, abci_app}
  end

  @doc """
  Specific query for nonces which provides zero for unknown senders
  """
  def handle_call(request_query(path: '/nonces' ++ address), _from,
  %HonteD.ABCI{consensus_state: consensus_state} = abci_app) do
    key = "nonces" <> to_string(address)
    value = Map.get(consensus_state, key, 0)
    reply = response_query(code: code(:ok), key: to_charlist(key), value: encode_query_response(value),
      proof: 'no proof')
    {:reply, reply, abci_app}
  end

  @doc """
  Specialized query for issued tokens for an issuer
  """
  def handle_call(request_query(path: '/issuers/' ++ address), _from,
  %HonteD.ABCI{consensus_state: consensus_state} = abci_app) do
    key = "issuers/" <> to_string(address)
    {code, value, log} = handle_get(State.issued_tokens(consensus_state, address))
    reply = response_query(code: code, key: to_charlist(key),
      value: encode_query_response(value), proof: 'no proof', log: log)
    {:reply, reply, abci_app}
  end

  @doc """
  Generic raw query for any key in state.

  TODO: interface querying the state out, so that state remains implementation detail
  """
  def handle_call(request_query(path: path), _from,
  %HonteD.ABCI{consensus_state: consensus_state} = abci_app) do
    "/" <> key = to_string(path)
    {code, value, log} = lookup(consensus_state, key)
    reply = response_query(code: code, key: to_charlist(key), value: encode_query_response(value),
      proof: 'no proof', log: log)
    {:reply, reply, abci_app}
  end

  def handle_call(request_init_chain(validators: validators), _from, %HonteD.ABCI{} = abci_app) do
    initial_validators =
      for validator(power: power, pub_key: pub_key) <- validators do
        %Validator{stake: power, tendermint_address: encode_pub_key(pub_key)}
      end

    state = %{abci_app | initial_validators: initial_validators}
    {:reply, response_init_chain(), state}
  end

  def handle_cast({:set_staking_state, %Staking{} = contract_state}, %HonteD.ABCI{} = abci_app) do
    {:noreply, %{abci_app | staking_state: contract_state}}
  end

  ### END GenServer

  defp move_to_next_epoch_if_epoch_changed(state) do
    if State.epoch_change?(state) do
      State.not_change_epoch(state)
    else
      state
    end
  end

  defp validators_diff(state, staking_state, initial_validators) do
    next_epoch = State.epoch_number(state)
    current_epoch = next_epoch - 1
    epoch_change = State.epoch_change?(state)
    cond do
      epoch_change and (current_epoch > 0) ->
        current_epoch_validators = staking_state.validators[current_epoch]
        next_epoch_validators = staking_state.validators[next_epoch]

        validators_diff(current_epoch_validators, next_epoch_validators)
      epoch_change ->
        next_epoch_validators = staking_state.validators[next_epoch]
        validators_diff(initial_validators, next_epoch_validators)
      true ->
        []
    end
  end

  defp validators_diff(current_epoch_validators, next_epoch_validators) do
    removed_validators = removed_validators(current_epoch_validators, next_epoch_validators)
    next_validators = next_validators(next_epoch_validators)

    (removed_validators ++ next_validators)
  end

  defp removed_validators(current_epoch_validators, next_epoch_validators) do
    removed_validators =
      tendermint_addresses(current_epoch_validators) -- tendermint_addresses(next_epoch_validators)
    Enum.map(removed_validators,
             fn tm_addr -> validator(pub_key: decode_pub_key(tm_addr), power: 0) end)
  end

  defp tendermint_addresses(validators), do: Enum.map(validators, &(&1.tendermint_address))

  defp next_validators(validators) do
    Enum.map(validators,
            fn %Validator{stake: stake, tendermint_address: tendermint_address} ->
              validator(pub_key: decode_pub_key(tendermint_address), power: stake)
            end)
  end

  # NOTE: <<1>> in this decode/encode functions, is tendermint/crypto's EC type 0x01, the only one we support now
  #       c.f. HonteStaking.sol function join
  defp decode_pub_key(pub_key), do: <<1>> <> Base.decode16!(pub_key)

  defp encode_pub_key(<<1>> <> pub_key), do: Base.encode16(pub_key)

  defp encode_query_response(object) do
    object
    |> Poison.encode!
    |> to_charlist
  end

  defp handle_tx(abci_app, %Transaction.SignedTx{raw_tx: %Transaction.EpochChange{}} = tx, extract_state) do
    with :ok <- HonteD.Transaction.Validation.valid_signed?(tx),
         do: State.exec(extract_state.(abci_app), tx, abci_app.staking_state)
  end

  defp handle_tx(abci_app, tx, extract_state) do
    with :ok <- HonteD.Transaction.Validation.valid_signed?(tx),
         do: State.exec(extract_state.(abci_app), tx)
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

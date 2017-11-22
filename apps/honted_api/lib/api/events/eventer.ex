defmodule HonteD.API.Events.Eventer do
  @moduledoc """
  Handles stream of send events from HonteD.ABCI and forwards them to subscribers.

  This implementation is as simple as it can be.

  Generic process registries are a bad fit since we want to hyper-optimize for
  particular use case (bloom filters etc).
  """
  use GenServer
  require Logger

  defmodule State do
    defstruct [subs: BiMultiMap.new(),
               filters: BiMultiMap.new(),
               monitors: Map.new(),
               committed: Map.new(),
               height: 1,
               tendermint: HonteD.API.TendermintRPC,
              ]

    @typep event :: HonteD.Transaction.t
    @typep topic :: HonteD.address
    @typep queue :: Qex.t({HonteD.block_height, event})
    @typep token :: HonteD.token

    @type t :: %State{
      subs: BiMultiMap.t([topic], pid),
      filters: BiMultiMap.t(HonteD.filter_id, {[topic], pid}),
      monitors: %{pid => reference},
      # Events that are waiting to be finalized.
      # Assumes one source of finality for each of the tokens.
      # Works ONLY for Send transactions
      # TODO: pull those events from Tendermint
      committed: %{optional(token) => queue},
      height: HonteD.block_height,
      tendermint: module(),
    }
  end

  def start_link(args, opts) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def child_spec(_) do
    %{id: __MODULE__,
      start: {__MODULE__, :start_link, [[], [name: __MODULE__]]},
      type: :worker,
      restart: :permanent,
    }
  end

  ## callbacks

  @spec init([map]) :: {:ok, State.t}
  def init([]), do: {:ok, %State{}}
  def init([%{tendermint: module}]), do: {:ok, %State{tendermint: module}}

  def handle_cast({:event, %HonteD.Transaction.Send{} = event, _}, state) do
    state = insert_committed(event, state)
    do_notify(:committed, event, state.subs)
    {:noreply, state}
  end

  def handle_cast({:event, %HonteD.Transaction.SignOff{} = event, tokens}, state) when is_list(tokens) do
    case check_valid_signoff?(event, state.tendermint) do
      true ->
        {:noreply, finalize_events(tokens, event.height, state)}
      false ->
        _ = Logger.debug("Dropped sign-off: #{inspect event}, #{inspect tokens}")
        {:noreply, state}
    end
  end

  def handle_cast({:event, %HonteD.API.Events.NewBlock{} = event, _}, state) do
    {:noreply, %{state | height: event.height}}
  end

  def handle_cast({:event, event, context}, state) do
    _ = Logger.warn("Warning: unhandled event #{inspect event} with context #{inspect context}")
    {:noreply, state}
  end

  def handle_cast(msg, state) do
    {:stop, {:unhandled_cast, msg}, state}
  end


  def handle_call({:new_filter, pid, topics}, _from, state) do
    mons = Map.put_new_lazy(state.monitors, pid, fn -> Process.monitor(pid) end)
    filter_id = make_ref()
    filters = BiMultiMap.put(state.filters, filter_id, {topics, pid})
    subs = BiMultiMap.put(state.subs, topics, pid)
    {:reply, {:ok, filter_id, state.height + 1}, %{state | subs: subs, monitors: mons, filters: filters}}
  end

  def handle_call({:drop_filter, filter_id}, _from, state) do
    case BiMultiMap.get(state.filters, filter_id, nil) do
      [{topics, pid}] ->
        state = drop_filter(filter_id, topics, pid, state)
        {:reply, :ok, state}
      nil ->
        {:reply, {:error, :notfound}, state}
    end
  end

  def handle_call({:status, filter_id}, _from, state) do
    case BiMultiMap.get(state.filters, filter_id) do
      [{topics, _}] ->
        {:reply, {:ok, topics}, state}
      _ ->
        {:reply, {:error, :notfound}, state}
    end
  end

  def handle_call(msg, from, state) do
    {:stop, {:unhandled_call, from, msg}, state}
  end


  def handle_info({:DOWN, _monref, :process, pid, _reason},
                  state = %{subs: subs, monitors: mons}) do
    mons = Map.delete(mons, pid)
    topics = BiMultiMap.get_keys(subs, pid)
    subs = BiMultiMap.delete_value(subs, pid)
    drop_filter_ids = fn(topics_group, acc) ->
      BiMultiMap.delete_value(acc, {topics_group, pid})
    end
    filters = Enum.reduce(topics, state.filters, drop_filter_ids)
    {:noreply, %{state | subs: subs, monitors: mons, filters: filters}}
  end

  def handle_info(msg, state) do
    {:stop, {:unhandled_info, msg}, state}
  end

  ## internals

  defp drop_filter(filter_id, topics, pid, state) do
    filters = BiMultiMap.delete(state.filters, filter_id, {topics, pid})
    subs = BiMultiMap.delete(state.subs, topics, pid)
    mons = case BiMultiMap.has_value?(subs, pid) do
             false ->
               state.monitors
             true ->
               Process.demonitor(state.monitors[pid], [:flush]);
               Map.delete(state.monitors, pid)
           end
    %{state | subs: subs, monitors: mons, filters: filters}
  end

  defp finalize_events(tokens, height, state) do
    notify_token = fn(token, acc_committed) ->
      # for a given token will process the queue with events and emit :finalized events to subscribers
      {events, acc_committed} = pop_finalized(token, height, acc_committed)
      for event <- events, do: do_notify(:finalized, event, state.subs)
      acc_committed
    end
    %{state | committed: Enum.reduce(tokens, state.committed, notify_token)}
  end

  defp insert_committed(event, state) do
    token = get_token(event)
    enqueue = fn(queue) -> Qex.push(queue, {state.height, event}) end
    committed = Map.update(state.committed, token, Qex.new([{state.height, event}]), enqueue)
    %{state | committed: committed}
  end

  defp pop_finalized(token, signed_off_height, committed) do
    split_queue_by_finalized_status = fn
      # should take a queue and split it into a list of finalized events and
      # a queue with the rest of {height, event}'s
      (nil) -> {[], nil}
      (queue) ->
        {finalized_tuples, rest} =
          HonteD.Transaction.Finality.split_finalized_events(queue, signed_off_height)
        # unzip to discard the heights and keep only the events
        {_, finalized} = Enum.unzip(finalized_tuples)
        {finalized, Qex.new(rest)}
    end
    Map.get_and_update(committed, token, split_queue_by_finalized_status)
  end

  def check_valid_signoff?(%HonteD.Transaction.SignOff{} = event, tendermint_module) do
    client = tendermint_module.client()
    with {:ok, blockhash} <- HonteD.API.Tools.get_block_hash(event.height, tendermint_module, client),
      do: HonteD.Transaction.Finality.valid_signoff?(event.hash, blockhash)
  end

  defp get_token(%HonteD.Transaction.Send{} = event) do
    event.asset
  end

  defp do_notify(event_type, event_content, all_subs) do
    pids = subscribed(event_topics_for(event_content), all_subs)
    _ = Logger.info("do_notify: #{inspect event_type}, #{inspect event_content}, pid: #{inspect pids}")
    prepared_message = message(event_type, event_content)
    for pid <- pids, do: send(pid, {:event, prepared_message})
    :ok
  end

  defp message(event_type, %HonteD.Transaction.Send{} = event_content)
  when event_type in [:committed, :finalized]
    do
    # FIXME: consider mappifying the tx: transaction: %{type: :send, payload: Map.from_struct(event_content)}
    %{source: :filter, type: event_type, transaction: event_content}
  end

  defp event_topics_for(%HonteD.Transaction.Send{to: dest}), do: [dest]

  # FIXME: this maps get should be done for set of all subsets
  defp subscribed(topics, subs) do
    BiMultiMap.get(subs, topics)
  end

end

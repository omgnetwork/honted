defmodule HonteD.Eventer do
  @moduledoc """
  Handles stream of send events from HonteD.ABCI and forwards them to subscribers.

  This implementation is as simple as it can be.

  Generic process registries are a bad fit since we want to hyper-optimize for
  particular use case (bloom filters etc).
  """
  use GenServer

  @typep topic2sub :: %{[binary] => MapSet}
  @typep sub2topic :: %{pid => MapSet}
  @typep state :: %{topic2sub: topic2sub(), sub2topic: sub2topic()}

  ## API

  def notify_committed(server \\ __MODULE__, event) do
    GenServer.cast(server, {:event, event})
  end

  def subscribe_send(server \\ __MODULE__, pid, receiver) do
    with true <- is_valid_subscriber(pid),
         true <- is_valid_topic(receiver),
    do: GenServer.call(server, {:subscribe, pid, [receiver]})
  end

  def unsubscribe_send(server \\ __MODULE__, pid, receiver) do
    with true <- is_valid_subscriber(pid),
         true <- is_valid_topic(receiver),
      do: GenServer.call(server, {:unsubscribe, pid, [receiver]})
  end

  def subscribed?(server \\ __MODULE__, pid, receiver) do
    with true <- is_valid_subscriber(pid),
         true <- is_valid_topic(receiver),
      do: GenServer.call(server, {:is_subscribed, pid, [receiver]})
  end

  def start_link(args, opts \\ [name: __MODULE__]) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  ## guards

  # Note that subscriber defined via registered atom is useless
  # as it will lead to loss of messages in case of its downtime.
  defp is_valid_subscriber(pid) when is_pid(pid), do: true
  defp is_valid_subscriber(_), do: {:error, :subscriber_must_be_pid}

  defp is_valid_topic(topic) when is_binary(topic), do: true
  defp is_valid_topic(_), do: {:error, :topic_must_be_a_string}

  ## callbacks

  @spec init([]) :: {:ok, state}
  def init([]) do
    {:ok, %{topic2sub: Map.new(),
            sub2topic: Map.new(),
            monitors: Map.new()}}
  end

  def handle_cast({:event, {_, :send, _, _, _, _, _} = event}, state) do
    do_notify(event, state[:topic2sub])
    {:noreply, state}
  end

  def handle_cast({:event, _}, state) do
    {:noreply, state}
  end

  def handle_cast(msg, state) do
    {:stop, {:unhandled_cast, msg}, state}
  end


  def handle_call({:subscribe, pid, topics}, _from, state) do
    mons = state[:monitors]
    mons = Map.put_new_lazy(mons, pid, fn -> Process.monitor(pid) end)
    {topic2sub, sub2topic} = do_subsribe(pid, topics, state[:topic2sub], state[:sub2topic])
    state = %{state | topic2sub: topic2sub, sub2topic: sub2topic, monitors: mons}
    {:reply, :ok, state}
  end

  def handle_call({:unsubscribe, pid, topics}, _from, state) do
    {do_demonitor, topic2sub, sub2topic} =
      do_unsubscribe(pid, topics, state[:topic2sub], state[:sub2topic])
    mons = case do_demonitor do
             false ->
               state[:monitors]
             true ->
               Process.demonitor(state[:monitors][pid], [:flush]);
               Map.delete(state[:monitors], pid)
           end
    {:reply, :ok, %{state | topic2sub: topic2sub, sub2topic: sub2topic, monitors: mons}}
  end

  def handle_call({:is_subscribed, pid, topics}, _from, state) do
    subs = subscribed(topics, state[:topic2sub])
    {:reply, {:ok, Enum.member?(subs, pid)}, state}
  end

  def handle_call(msg, from, state) do
    {:stop, {:unhandled_call, from, msg}, state}
  end


  def handle_info({:DOWN, _monref, :process, pid, _reason},
                  state = %{topic2sub: topic2sub, sub2topic: sub2topic, monitors: mons}) do
    mons = Map.delete(mons, pid)
    {topics_list, sub2topic} = Map.pop(sub2topic, pid, MapSet.new())
    cleanup_pid = fn(topics, acc) ->
      {_, acc} = mms_delete(acc, topics, pid)
      acc
    end
    topic2sub = Enum.reduce(topics_list, topic2sub, cleanup_pid)
    {:noreply, %{state | topic2sub: topic2sub, sub2topic: sub2topic, monitors: mons}}
  end

  def handle_info(msg, state) do
    {:stop, {:unhandled_info, msg}, state}
  end

  ## internals

  defp do_subsribe(pid, topics, topic2sub, sub2topic) do
    topic2sub = mms_insert(topic2sub, topics, pid)
    sub2topic = mms_insert(sub2topic, pid, topics)
    {topic2sub, sub2topic}
  end

  defp do_unsubscribe(pid, topics, topic2sub, sub2topic) do
    {_, topic2sub} = mms_delete(topic2sub, topics, pid)
    {more_or_pop, sub2topic} = mms_delete(sub2topic, pid, topics)
    do_demonitor = more_or_pop == :pop
    {do_demonitor, topic2sub, sub2topic}
  end

  @spec mms_insert(%{key => MapSet.t(value)}, key, value)
  :: %{key => MapSet.t(value)} when value: any, key: any
  def mms_insert(map, key, value) do
    Map.update(map, key, MapSet.new([value]), &(MapSet.put(&1, value)))
  end

  @spec mms_delete(%{key => MapSet.t(value)}, key, value)
    :: {:pop | :more, %{key => MapSet.t(value)}} when value: any, key: any
  def mms_delete(map, key, value) do
    updatefn = fn(mapset) ->
      mapset = MapSet.delete(mapset, value)
      case MapSet.size(mapset) do
        0 -> :pop
        _ -> {:more, mapset}
      end
    end
    Map.get_and_update(map, key, updatefn)
  end

  defp do_notify(event, all_subs) do
    pids = subscribed(event_topics(event), all_subs)
    for pid <- pids, do: send(pid, {:committed, event})
  end

  defp event_topics({_, :send, _, _, _, dest, _}), do: [dest]

  # FIXME: this maps get should be done for set of all subsets
  defp subscribed(topics, subs) do
    MapSet.to_list(Map.get(subs, topics, MapSet.new()))
  end

end

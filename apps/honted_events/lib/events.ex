defmodule HonteD.Events do
  @moduledoc """
  Public API for the HonteD.Events.Eventer GenServer
  """
  
  @server HonteD.Events.Eventer

  @doc """
  Makes eventer send a :committed event to subscrubers.
  
  See `defp message` for reference of messages sent to subscribing pids
  """
  def notify_committed(server \\ @server, event_content) do
    GenServer.cast(server, {:event, :committed, event_content})
  end

  def subscribe_send(server \\ @server, pid, receiver) do
    with true <- is_valid_subscriber(pid),
         true <- is_valid_topic(receiver),
    do: GenServer.call(server, {:subscribe, pid, [receiver]})
  end

  def unsubscribe_send(server \\ @server, pid, receiver) do
    with true <- is_valid_subscriber(pid),
         true <- is_valid_topic(receiver),
      do: GenServer.call(server, {:unsubscribe, pid, [receiver]})
  end

  def subscribed?(server \\ @server, pid, receiver) do
    with true <- is_valid_subscriber(pid),
         true <- is_valid_topic(receiver),
      do: GenServer.call(server, {:is_subscribed, pid, [receiver]})
  end

  def start_link(args, opts \\ [name: @server]) do
    GenServer.start_link(@server, args, opts)
  end

  ## guards

  # Note that subscriber defined via registered atom is useless
  # as it will lead to loss of messages in case of its downtime.
  defp is_valid_subscriber(pid) when is_pid(pid), do: true
  defp is_valid_subscriber(_), do: {:error, :subscriber_must_be_pid}

  defp is_valid_topic(topic) when is_binary(topic), do: true
  defp is_valid_topic(_), do: {:error, :topic_must_be_a_string}
  
end

defmodule HonteD.Events do
  @moduledoc """
  Public API for the HonteD.Events.Eventer GenServer
  """

  @type badarg :: :subscriber_must_be_pid | :topic_must_be_a_string
  @type event :: HonteD.Transaction.t | HonteD.Events.NewBlock.t

  @server HonteD.Events.Eventer

  defmodule NewBlock do
    defstruct [:height]

    @type t :: %NewBlock{
      height: HonteD.block_height
    }
  end

  @doc """
  Makes eventer send a :committed event to subscribers.

  See `defp message` for reference of messages sent to subscribing pids
  """
  @spec notify(server :: atom | pid, event :: event, list(HonteD.token) | any) :: :ok
  def notify(server \\ @server, event, context) do
    GenServer.cast(server, {:event, event, context})
  end

  @spec new_send_filter(server :: atom | pid, pid :: pid, receiver :: HonteD.address) :: :ok | {:error, badarg}
  def new_send_filter(server \\ @server, pid, receiver) do
    with true <- is_valid_subscriber(pid),
         true <- is_valid_topic(receiver),
    do: GenServer.call(server, {:subscribe, pid, [receiver]})
  end

  @spec drop_send_filter(server :: atom | pid, subscriber :: pid, watched :: HonteD.address)
  :: :ok | {:error, HonteD.Events.badarg}
  def drop_send_filter(server \\ @server, pid, receiver) do
    with true <- is_valid_subscriber(pid),
         true <- is_valid_topic(receiver),
      do: GenServer.call(server, {:unsubscribe, pid, [receiver]})
  end

  @spec status_send_filter?(server :: atom | pid, subscriber :: pid, watched :: HonteD.address)
  :: {:ok, boolean} | {:error, HonteD.Events.badarg}
  def status_send_filter?(server \\ @server, pid, receiver) do
    with true <- is_valid_subscriber(pid),
         true <- is_valid_topic(receiver),
      do: GenServer.call(server, {:is_subscribed, pid, [receiver]})
  end

  ## guards

  # Note that subscriber defined via registered atom is useless
  # as it will lead to loss of messages in case of its downtime.
  defp is_valid_subscriber(pid) when is_pid(pid), do: true
  defp is_valid_subscriber(_), do: {:error, :subscriber_must_be_pid}

  defp is_valid_topic(topic) when is_binary(topic), do: true
  defp is_valid_topic(_), do: {:error, :topic_must_be_a_string}

end

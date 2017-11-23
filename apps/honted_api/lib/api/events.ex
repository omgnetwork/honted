defmodule HonteD.API.Events do
  @moduledoc """
  Public API for the HonteD.API.Events.Eventer GenServer
  """

  @type badarg :: :subscriber_must_be_pid | :topic_must_be_a_string | :bad_block_height
                | :filter_id_must_be_a_reference
  @type event :: HonteD.Transaction.t | HonteD.API.Events.NewBlock.t

  @server HonteD.API.Events.Eventer

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
  
  @spec notify(server :: atom | pid, event :: event) :: :ok
  def notify_without_context(server \\ @server, event) do
    GenServer.cast(server, {:event, event})
  end
  
  @spec new_send_filter_history(server :: atom | pid, pid :: pid, receiver :: HonteD.address,
                                first :: HonteD.block_height, last :: HonteD.block_height)
    :: {:ok, HonteD.filter_id} | {:error, badarg}
  def new_send_filter_history(server \\ @server, pid, receiver, first, last) do
    # FIXME checks
    GenServer.call(server, {:new_filter_history, pid, [receiver], first, last})
  end
  
  @spec new_send_filter(server :: atom | pid, pid :: pid, receiver :: HonteD.address)
    :: {:ok, %{reference: HonteD.filter_id, start_height: HonteD.block_height}} | {:error, badarg}
  def new_send_filter(server \\ @server, pid, receiver) do
    with true <- is_valid_subscriber(pid),
         true <- is_valid_topic(receiver),
    do: GenServer.call(server, {:new_filter, pid, [receiver]})
  end

  @spec drop_filter(server :: atom | pid, filter_id :: HonteD.filter_id)
    :: :ok | {:error, :notfound | HonteD.API.Events.badarg}
  def drop_filter(server \\ @server, filter_id) do
    with true <- is_valid_reference(filter_id),
      do: GenServer.call(server, {:drop_filter, filter_id})
  end

  @spec status_filter(server :: atom | pid, filter_id :: HonteD.filter_id)
    :: {:ok, [binary]} | {:error, :noutfound | HonteD.API.Events.badarg}
  def status_filter(server \\ @server, filter_id) do
    with true <- is_valid_reference(filter_id),
      do: GenServer.call(server, {:status, filter_id})
  end

  ## guards

  # Note that subscriber defined via registered atom is useless
  # as it will lead to loss of messages in case of its downtime.
  defp is_valid_subscriber(pid) when is_pid(pid), do: true
  defp is_valid_subscriber(_), do: {:error, :subscriber_must_be_pid}

  defp is_valid_topic(topic) when is_binary(topic), do: true
  defp is_valid_topic(_), do: {:error, :topic_must_be_a_string}

  defp is_valid_height(:current), do: true
  defp is_valid_height(height) when is_integer(height) and height > 0, do: true
  defp is_valid_height(_), do: {:error, :bad_block_height}

  defp is_valid_reference(ref) when is_reference(ref), do: true
  defp is_valid_reference(_), do: {:error, :filter_id_must_be_a_reference}

end

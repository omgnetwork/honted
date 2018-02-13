defmodule HonteD.ABCI.Ethereum.EthashCacheServer do
  @moduledoc """
  Stores cache for ethash
  """
  use GenServer

  @epoch_length 30_000 # Epoch length in number of blocks. Cache is the same for each block in an epoch.
  @timeout 600_000

  alias HonteD.ABCI.Ethereum.EthashCache

  @doc """
  Starts cache store
  """
  def start(block_number) do
    epoch = epoch(block_number)
    cache = EthashCache.make_cache(block_number)
    GenServer.start_link(__MODULE__, %{epoch => cache}, [name: __MODULE__])
  end

  @doc """
  Gets cache for a given block number
  """
  def get_cache(block_number) do
    GenServer.call(__MODULE__, {:get, block_number}, @timeout)
  end

  def handle_call({:get, block_number}, _from, state) do
    epoch = epoch(block_number)
    case Map.fetch(state, epoch) do
      {:ok, cache} -> {:reply, {:ok, cache}, state}
      :error -> {:reply, :missing_cache, state}
    end
  end

  defp epoch(block_number), do: div(block_number, @epoch_length)

end

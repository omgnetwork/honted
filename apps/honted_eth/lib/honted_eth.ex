defmodule HonteD.Eth do
  @moduledoc """
  Tracks state of geth synchronization and state of staking contract and feeds it to ABCI state machine.
  """

  require Logger
  use GenServer

  alias Ethereumex.HttpClient, as: RPC

  defstruct [failed: 0,
             max: 120,
             contract: nil
            ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    staking = Application.get_env(:honted_eth, :staking_contract_address)
    enabled = Application.get_env(:honted_eth, :enabled)
    case {enabled, syncing?()} do
      {false, _} ->
        :ignore
      {true, false} ->
        Process.send_after(self(), :check_sync_state, 1000)
        Process.send_after(self(), :fetch_validators, 10_000)
        {:ok, %__MODULE__{contract: staking}}
      {true, true} ->
        {:stop, :honted_requires_geth_to_be_synchronized}
    end
  end

  def handle_call(_, _from, state) do
    {:reply, {:error, :unknown_call}, state}
  end

  def handle_info(:check_sync_state, state) do
    Process.send_after(self(), :check_sync_state, 1000)
    case syncing?() do
      true ->
        {:noreply, %{state | failed: state.failed + 1}}
      false ->
        {:noreply, %{state | failed: 0}}
    end
  end

  def handle_info(:fetch_validators, state = %{contract: staking}) do
    validators = HonteD.Eth.Contract.read_validators(staking)
    {:ok, epoch} = HonteD.Eth.Contract.get_current_epoch(staking)
    synced = state.failed < state.max
    contract_state = %{validators: validators, epoch: epoch, synced: synced}
    GenServer.cast(HonteD.ABCI, {:eth_validators, contract_state})
    {:noreply, state}
  end

  defp syncing? do
    try do
      sync = RPC.eth_syncing()
      case sync do
        {:ok, syncing} when is_boolean(syncing) -> syncing
        {:ok, _} -> true
      end
    catch
      _other ->
        true
      _class, _type ->
        true
    end
  end

end

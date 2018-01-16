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
        {:ok, %__MODULE__{contract: staking}}
      {true, true} ->
        {:stop, :honted_requires_geth_to_be_synchronized}
    end
  end

  def handle_call(_, _from, state) do
    {:reply, {:ok, state.contract}, state}
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

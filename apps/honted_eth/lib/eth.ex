defmodule HonteD.Eth do
  @moduledoc """
  Tracks state of geth synchronization (see :check_sync_state).
  Also periodically fetches staking contract state from Ethereum and sends
  it to ABCI state machine (see :fetch_validators).
  """

  require Logger
  use GenServer

  defstruct [enabled: false,
             failed_sync_checks: 0, # counts consecutive failed geth sync checks
             failed_sync_checks_max: 120,
             contract_address: nil,
             api: HonteD.Eth.Contract,
             refresh_period: 1000,
             sync_check_period: 1000,
            ]

  def contract_state do
    case enabled?() do
      false ->
        stub = %HonteD.Staking{ethereum_block_height: 10,
                               start_block: 2,
                               epoch_length: 30,
                               maturity_margin: 2,
                               validators: %{},
                               synced: true}
        {:ok, stub}
      true ->
        GenServer.call(HonteD.Eth, :contract_state)
    end
  end

  def start_link(opts) do
    staking = Application.get_env(:honted_eth, :staking_contract_address)
    state = %__MODULE__{enabled: enabled?(), contract_address: staking}
    GenServer.start_link(__MODULE__, state, opts)
  end

  # GenServer callbacks

  def init(state) do
    case {state.enabled, state.api.syncing?()} do
      {false, _} ->
        _ = Logger.warn(fn -> "Tracking the staking contract is disabled. Proceed with caution!" end)
        :ignore
      {true, false} ->
        # start the scheduled pushes to ABCI here
        send(self(), :check_sync_state)
        send(self(), :fetch_validators)
        {:ok, state}
      {true, true} ->
        {:stop, :honted_requires_geth_to_be_synchronized}
    end
  end

  def handle_call(:contract_state, _from, state) do
    contract_state = get_contract_state(state)
    {:reply, {:ok, contract_state}, state}
  end
  def handle_call(_, _from, state) do
    {:reply, {:error, :unknown_call}, state}
  end

  def handle_info(:check_sync_state, state) do
    Process.send_after(self(), :check_sync_state, state.sync_check_period)
    case state.api.syncing?() do
      true ->
        {:noreply, %{state | failed_sync_checks: state.failed_sync_checks + 1}}
      false ->
        {:noreply, %{state | failed_sync_checks: 0}}
    end
  end

  def handle_info(:fetch_validators, state) do
    Process.send_after(self(), :fetch_validators, state.refresh_period)
    contract_state = get_contract_state(state)
    case contract_state.synced do
      false ->
        {:stop, :honted_requires_geth_to_be_synchronized, state}
      true ->
        GenServer.cast(HonteD.ABCI, {:set_staking_state, contract_state})
        {:noreply, state}
    end
  end

  # private functions

  defp enabled? do
    Application.get_env(:honted_eth, :enabled, false)
  end

  defp get_contract_state(%{contract_address: staking, api: api} = state) do
    {:ok, start_block} = api.start_block(staking)
    {:ok, epoch_length} = api.epoch_length(staking)
    {:ok, maturity_margin} = api.maturity_margin(staking)
    synced = state.failed_sync_checks < state.failed_sync_checks_max
    %HonteD.Staking{ethereum_block_height: api.block_height(),
                    start_block: start_block,
                    epoch_length: epoch_length,
                    maturity_margin: maturity_margin,
                    validators: api.read_validators(staking),
                    synced: synced}
  end
end

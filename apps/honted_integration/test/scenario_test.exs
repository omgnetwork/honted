defmodule HonteD.Perf.ScenarioTest do
  @moduledoc """
  Unit test for performance scenario generation.
  Check is done on abci.state level - no IO is involved.
  """

  alias HonteD.ABCI.State, as: State
  import HonteD.Perf.Scenario

  use ExUnit.Case, async: true

  def run(scenario, n) do
    state =
      scenario
      |> get_setup()
      |> List.flatten()
      |> Enum.reduce(State.empty(), &apply_tx/2)
    hd(scenario.send_txs)
    |> Enum.take(n)
    |> Enum.reduce(state, &apply_tx/2)
  end

  def apply_tx({success_expected, tx}, state) do
    {:ok, decoded} = HonteD.TxCodec.decode(tx)
    # Signature check is needed to properly simulate abci/state behavior.
    :ok = HonteD.Transaction.Validation.valid_signed?(decoded)
    case State.exec(state, decoded) do
      {:ok, state} when success_expected -> state
      {:error, :insufficient_funds} when not success_expected -> state
    end
  end

  describe "Test scenario generation correctness." do
    test "Scenario executes: setup and load from one of the senders" do
      run(HonteD.Perf.Scenario.new(2, 10), 10)
    end

    test "Scenario.new/2 crashes for strange values." do
      catch_error(HonteD.Perf.Scenario.new(0, 10))
      catch_error(HonteD.Perf.Scenario.new(10, 0))
    end

    test "Scenarios are deterministic." do
      scenario1 = HonteD.Perf.Scenario.new(2, 10)
      run1 = Enum.take(hd(scenario1.send_txs), 10)
      scenario2 = HonteD.Perf.Scenario.new(2, 10)
      run2 = Enum.take(hd(scenario2.send_txs), 10)
      assert run1 == run2
    end

    test "Scenarios are not identical." do
      scenario1 = HonteD.Perf.Scenario.new(2, 10)
      run1 = Enum.take(hd(scenario1.send_txs), 10)
      scenario3 = HonteD.Perf.Scenario.new(3, 10)
      run3 = Enum.take(hd(scenario3.send_txs), 10)
      assert run1 != run3
    end
  end

end

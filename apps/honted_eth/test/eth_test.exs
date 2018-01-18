defmodule HonteD.EthTest do
  use ExUnit.Case
  doctest HonteD.Eth

  use ExUnit.Case, async: false
  import Mox

  @moduletag :eth

  defp get_mock do
    set_mox_global()
    HonteD.Eth.TestContract
  end

  defp mock_synced_geth(mock) do
    mock
    |> expect(:syncing?, 10, fn() -> false end)
  end

  defp mock_failing_geth(mock) do
    mock
    |> expect(:syncing?, 1, fn() -> false end)
    |> expect(:syncing?, 10, fn() ->
      send(HonteD.ABCI, :expect_desync)
      true
    end)
    |> expect(:syncing?, 10, fn() ->
      send(HonteD.ABCI, :expect_resync)
      false
    end)
  end

  defp mock_epoch_zero(mock) do
    mock
    |> expect(:start_block, 10, fn(_) -> {:ok, 1} end)
    |> expect(:epoch_length, 10, fn(_) -> {:ok, 10} end)
    |> expect(:maturity_margin, 10, fn(_) -> {:ok, 2} end)
    |> expect(:get_current_epoch, 10, fn(_) -> {:ok, 0} end)
    |> expect(:read_validators, 10, fn(_) -> vals() end)
    |> expect(:block_height, 10, fn() -> 9 end)
  end

  defp vals do
    %{1 => [%HonteD.Validator{}]}
  end

  setup_all do
    Application.load(:honted_eth)
    start_supervised Mox.Server
    %{}
  end

  describe "Eth server correctly processes startup conditions." do
    test "It can be disabled via config." do
      :ok = Application.put_env(:honted_eth, :enabled, false)
      assert :ignore = GenServer.start_link(HonteD.Eth, %HonteD.Eth{}, [])
    end

    test "It crashes on start if geth is not synchronized." do
      :ok = Application.put_env(:honted_eth, :enabled, true)
      Process.flag(:trap_exit, true)
      assert {:error, _} = GenServer.start_link(HonteD.Eth, %HonteD.Eth{}, [])
    end

    test "Starts if geth is synchronized." do
      :ok = Application.put_env(:honted_eth, :enabled, true)
      state = %HonteD.Eth{api: (get_mock() |> mock_synced_geth())}
      assert {:ok, _} = GenServer.start_link(HonteD.Eth, state, [])
    end

    test "Eth updates ABCI and replies when asked for contract state" do
      :ok = Application.put_env(:honted_eth, :enabled, true)
      mock =
        get_mock()
        |> mock_synced_geth()
        |> mock_epoch_zero()
      Process.register(self(), HonteD.ABCI)
      state = %HonteD.Eth{api: mock,
                          refresh_period: 10}
      assert {:ok, _} = GenServer.start_link(HonteD.Eth, state, [name: HonteD.Eth])
      {:ok, _} = HonteD.Eth.contract_state()
      assert_receive({:"$gen_cast", {:set_staking_state, _}}, 50)
      Process.unregister(HonteD.ABCI)
    end

    test "Eth detects geth changes in geth sync status." do
      :ok = Application.put_env(:honted_eth, :enabled, true)
      mock =
        get_mock()
        |> mock_epoch_zero()
        |> mock_failing_geth()
      Process.register(self(), HonteD.ABCI)
      state = %HonteD.Eth{api: mock,
                          failed: 0,
                          max: 2,
                          refresh_period: 25,
                          sync_check_period: 10}
      assert {:ok, _} = GenServer.start_link(HonteD.Eth, state, [name: HonteD.Eth])
      assert_receive({:"$gen_cast", {:set_staking_state, %HonteD.Staking{synced: true}}}, 60)
      assert_receive(:expect_desync, 100)
      assert_receive({:"$gen_cast", {:set_staking_state, %HonteD.Staking{synced: false}}}, 61)
      assert_receive(:expect_resync, 100)
      assert_receive({:"$gen_cast", {:set_staking_state, %HonteD.Staking{synced: true}}}, 62)
      Process.unregister(HonteD.ABCI)
    end
  end
end

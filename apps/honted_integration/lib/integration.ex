defmodule HonteD.Integration do
  @moduledoc """
  The intention is to have an app that depends on all other apps, which could serve as the place to put
  integration tests
  """

  require Logger

  def homedir do
    Temp.track!
    Temp.mkdir!(%{prefix: "honted_tendermint_test_homedir"})
  end

  def geth do
    IO.puts("integration.geth()")
    {ref, _} = HonteD.Eth.Geth.dev_geth()
    {:ok, token, staking} = HonteD.Eth.Geth.dev_deploy()
    Application.put_env(:honted_eth, :token_contract_address, token)
    Application.put_env(:honted_eth, :staking_contract_address, staking)
    on_exit = fn() ->
      HonteD.Eth.Geth.geth_stop(ref)
    end
    {:ok, on_exit}
  end

  @doc """
  Runs a HonteD ABCI app using Porcelain
  """
  def honted do
    IO.puts("integration.honted()")
    # handles a setup/teardown of our apps, that talk to similarly setup/torndown tendermint instances
    our_apps_to_start = [:honted_eth, :honted_api, :honted_abci, :honted_ws, :honted_jsonrpc]
    started_apps =
      our_apps_to_start
      |> Enum.map(&Application.ensure_all_started/1)
      |> Enum.flat_map(fn {:ok, app_list} -> app_list end) # check if successfully started here!
    {:ok, fn ->
      started_apps
      |> Enum.map(&Application.stop/1)
    end}
  end

  @doc """
  Inits a temporary tendermint chain and runs a node connecting to HonteD
  Waits till node is up
  """
  def tendermint(homedir) do
    %Porcelain.Result{err: nil, status: 0} = Porcelain.shell(
      "tendermint --home #{homedir} init"
    )

    # start tendermint and capture the stdout
    tendermint_proc = %Porcelain.Process{err: nil, out: tendermint_out} = Porcelain.spawn_shell(
      "tendermint --home #{homedir} --log_level \"*:info\" node",
      out: :stream,
    )
    wait_for_tendermint_start(tendermint_out)

    # something to give us the possibility to look at blocks being mined
    _ = Task.async(fn -> show_tendermint_logs(tendermint_out) end)

    {:ok, fn ->
      Porcelain.Process.stop(tendermint_proc)
    end}
  end

  ### HELPER FUNCTIONS

  defp show_tendermint_logs(tendermint_out) do
    tendermint_out
    |> Stream.flat_map(&String.split(&1, "\n")) # necessary because items in stream are >1 line
    |> Stream.filter(fn line -> String.contains?(line, "Executed block") end)
    |> Enum.each(&Logger.info/1)
  end

  defp wait_for_tendermint_start(tendermint_out) do
    wait_for_start(tendermint_out, "Started node", 20_000)
  end

  def wait_for_start(outstream, look_for, timeout) do
    # Monitors the stdout coming out of a process for signal of successful startup
    waiting_task_function = fn ->
      outstream
      |> Stream.take_while(fn line -> not String.contains?(line, look_for) end)
      |> Enum.to_list
    end

    waiting_task_function
    |> Task.async
    |> Task.await(timeout)

    :ok
  end
end

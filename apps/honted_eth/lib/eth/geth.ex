defmodule HonteD.Eth.Geth do
  @moduledoc """
  Helper module for deployment of contracts to dev geth.
  """

  alias HonteD.Eth.WaitFor, as: WaitFor

  def dev_geth do
    Temp.track!
    homedir = Temp.mkdir!(%{prefix: "honted_eth_test_homedir"})
    res = geth("geth --dev --rpc --datadir " <> homedir <> " 2>&1")
    {:ok, :ready} = WaitFor.rpc()
    res
  end

  def dev_deploy do
    {:ok, _token, _staking} = HonteD.Eth.Contract.deploy(20, 2, 5)
  end

  def geth(cmd \\ "geth --rpc") do
    IO.puts("starting #{inspect cmd}")
    geth_proc = %Porcelain.Process{err: nil, out: geth_out} = Porcelain.spawn_shell(
      cmd,
      out: :stream,
    )
    wait_for_geth_start(geth_out)
    {geth_proc, geth_out}
  end

  def geth_stop(pid) do
    Porcelain.Process.stop(pid)
  end

  # PRIVATE
  defp wait_for_geth_start(geth_out) do
    wait_for_start(geth_out, "IPC endpoint opened", 3000)
  end

  defp wait_for_start(outstream, look_for, timeout) do
    # Monitors the stdout coming out of a process for signal of successful startup
    waiting_task_function = fn ->
      outstream
      |> Stream.take_while(fn line -> not String.contains?(line, look_for) end)
      |> Enum.to_list
    end
    WaitFor.function(waiting_task_function, timeout)
  end

end

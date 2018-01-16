defmodule HonteD.Integration.Geth do
  @moduledoc """
  Helper module for deployment of contracts to dev geth.
  """

  def dev_geth do
    Temp.track!
    homedir = Temp.mkdir!(%{prefix: "honted_eth_test_homedir"})
    res = geth("geth --dev --rpc --datadir " <> homedir <> " 2>&1")
    {:ok, :ready} = HonteD.Eth.WaitFor.rpc()
    res
  end

  def geth_stop(pid, os_pid) do
    # FIXME: goon is broken, and because of that signal does not work and we do kill -9 instead
    #        Same goes for basic driver.
    # Porcelain.Process.signal(pid, :kill)
    Porcelain.Process.stop(pid)
    cmd = String.to_charlist("kill -9 #{os_pid}")
    IO.puts("doing this: #{cmd}")
    :os.cmd(cmd)
  end

  # PRIVATE
  defp geth(cmd) do
    geth_pids = geth_os_pids()
    geth_proc = %Porcelain.Process{err: nil, out: geth_out} = Porcelain.spawn_shell(
      cmd,
      out: :stream,
    )
    geth_pids_after = geth_os_pids()
    wait_for_geth_start(geth_out)
    [geth_os_pid] = geth_pids_after -- geth_pids
    geth_os_pid = String.trim(geth_os_pid)
    {geth_proc, geth_os_pid, geth_out}
  end

  defp geth_os_pids do
    'pidof geth'
    |> :os.cmd
    |> List.to_string
    |> String.trim
    |> String.split
  end

  defp wait_for_geth_start(geth_out) do
    wait_for_start(geth_out, "IPC endpoint opened", 3000)
  end

  defp wait_for_start(outstream, look_for, timeout) do
    IO.puts("waiting for: #{inspect look_for}")
    # Monitors the stdout coming out of a process for signal of successful startup
    waiting_task_function = fn ->
      outstream
      |> Stream.take_while(fn line ->
        res = not String.contains?(line, look_for)
        IO.puts("found: #{inspect res}; geth prints: #{inspect line}")
        res
      end)
      |> Enum.to_list
      IO.puts("returning from waiting")
      :ok
    end
    HonteD.Eth.WaitFor.function(waiting_task_function, timeout)
    IO.puts("returning from wait_for_start")
  end
end

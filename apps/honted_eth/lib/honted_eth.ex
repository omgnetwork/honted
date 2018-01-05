defmodule HonteD.Eth do
  @moduledoc """
  Documentation for HonteD.Eth.
  """

  def launch_and_deploy do
    {pid, _} = dev_geth()
    :ready = rpc_ready?()
    deploy()
    geth_stop(pid)
  end

  def deploy do
    cmd = "./deploy.py"
    deploy_proc = %Porcelain.Process{err: nil, out: depl_out} = Porcelain.spawn_shell(
      cmd,
      out: :stream,
    )
  end

  def dev_geth do
    Temp.track!
    homedir = Temp.mkdir!(%{prefix: "honted_eth_test_homedir"})
    geth("geth --rpc --datadir " <> homedir <> " 2>&1")
  end

  def geth(cmd \\ "geth --rpc") do
    IO.puts("starting #{inspect cmd}")
    geth_proc = %Porcelain.Process{err: nil, out: geth_out} = Porcelain.spawn_shell(
      cmd,
      out: :stream,
    )
    :ok = wait_for_geth_start(geth_out)
    {geth_proc, geth_out}
  end

  def geth_stop(pid) do
    Porcelain.Process.stop(pid)
  end

  # PRIVATE

  defp wait_for_geth_start(geth_out) do
    wait_for_start(geth_out, "IPC endpoint opened", 3000)
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

  def rpc_ready?() do
    ref = Task.async(fn ->
      check_sync_until_ready()
    end)
    Task.await(ref, :infinity)
  end

  defp check_sync_until_ready do
    case Ethereumex.HttpClient.eth_syncing() do
      {:ok, false} ->
        :ready
      other ->
        IO.puts("syncing: #{inspect other}")
        Process.sleep(1000)
        check_sync_until_ready()
    end
  end

end

defmodule HonteD.Integration.Fixtures do
  use ExUnitFixtures.FixtureModule
  
  @startup_timeout 20000
  
  deffixture homedir() do
    {:ok, dir_path} = Temp.mkdir("tendermint")
    on_exit fn ->
      {:ok, _} = File.rm_rf(dir_path)
    end
    dir_path
  end
  
  deffixture tendermint(homedir, honted) do
    # we just depend on honted running, so match to prevent compiler woes
    :ok = honted
    
    %Porcelain.Result{err: nil, status: 0} = Porcelain.shell(
      "tendermint --home #{homedir} init"
    )
    
    # start tendermint and capture the stdout
    tendermint_proc = %Porcelain.Process{err: nil, out: tendermint_out} = Porcelain.spawn_shell(
      "tendermint --home #{homedir} --log_level \"*:info\" node",
      out: :stream,
    )
    :ok = 
      fn -> wait_for_tendermint_start(tendermint_out) end
      |> Task.async
      |> Task.await(@startup_timeout)
      
    on_exit fn -> 
      Porcelain.Process.stop(tendermint_proc)
    end
  end
  
  deffixture honted() do
    # handles a setup/teardown of our apps, that talk to similarly setup/torndown tendermint instances
    our_apps_to_start = [:honted_api, :honted_abci, :honted_ws, :honted_jsonrpc]
    started_apps = 
      our_apps_to_start
      |> Enum.map(&Application.ensure_all_started/1)
      |> Enum.flat_map(fn {:ok, app_list} -> app_list end) # check if successfully started here!
    on_exit fn -> 
      started_apps
      |> Enum.map(&Application.stop/1)
    end
    :ok
  end
  
  defp wait_for_tendermint_start(outstream) do
    # monitors the stdout coming out of Tendermint for signal of successful startup
    outstream
    |> Stream.take_while(fn line -> not String.contains?(line, "Started node") end)
    |> Enum.to_list
    :ok
  end
  

end

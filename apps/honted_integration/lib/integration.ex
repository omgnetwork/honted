defmodule HonteD.Integration do
  @moduledoc """
  The intention is to have an app that depends on all other apps, which could serve as the place to put 
  integration tests
  """
  
  alias HonteD.{Crypto, API}
  
  require Logger
  
  def homedir() do
    {:ok, dir_path} = Temp.mkdir("tendermint")
    {dir_path, fn ->
      {:ok, _} = File.rm_rf(dir_path)
    end}
  end
  
  @doc """
  Runs a HonteD ABCI app using Porcelain
  """
  def honted() do
    # handles a setup/teardown of our apps, that talk to similarly setup/torndown tendermint instances
    our_apps_to_start = [:honted_api, :honted_abci, :honted_ws, :honted_jsonrpc]
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
    {:ok, fn -> 
      Porcelain.Process.stop(tendermint_proc)
    end}
  end 
   
  def tm_bench(duration_T) do
    # start tendermint and capture the stdout
    tm_bench_proc = %Porcelain.Process{err: nil, out: tm_bench_out} = Porcelain.spawn_shell(
      "tm-bench -c 0 -T #{duration_T} localhost:46657",
      out: :stream,
    )
    :ok = wait_for_tm_bench_start(tm_bench_out)
    
    {tm_bench_proc, tm_bench_out}
  end
  
  def dummy_txs_source(nstreams) do
    for stream_id <- 1..nstreams do
      Stream.interval(0)
      # FIXME: useful for debugging, remove after sprint
      # |> Stream.map(fn tx_id -> IO.puts("stream: #{stream_id}, tx: #{tx_id}"); tx_id end)
      |> Stream.map(fn _ -> 
        {:ok, issuer_priv} = Crypto.generate_private_key()
        {:ok, issuer_pub} = Crypto.generate_public_key(issuer_priv)
        {:ok, issuer} = Crypto.generate_address(issuer_pub)
        {:ok, raw_tx} = HonteD.Transaction.create_create_token(nonce: 0, issuer: issuer)
        {:ok, signature} = Crypto.sign(raw_tx, issuer_priv)
        raw_tx <> " " <> signature
      end)
    end
  end
  
  @doc """
  Fills the state a bit using txs source
  """
  def fill_in(txs_source, fill_in_per_stream) do
    fill_tasks = for txs_stream <- txs_source, do: Task.async(fn ->
      txs_stream
      |> Stream.take(fill_in_per_stream)
      |> Enum.map(fn tx -> HonteD.API.submit_transaction_async(tx) end)
    end)
      
    for task <- fill_tasks, do: Task.await(task, 100000)
  end
  
  def run_performance_test(txs_source, durationT) do
    _ = Logger.info("starting tm-bench")
    {tm_bench_proc, tm_bench_out} = tm_bench(durationT)
    
    for txs_stream <- txs_source, do: Task.async(fn ->
      txs_stream
      |> Enum.map(fn tx -> API.submit_transaction_async(tx) end)
    end)
    
    Porcelain.Process.await(tm_bench_proc, durationT * 1000 + 1000)
    tm_bench_out
  end
  
  ### HELPER FUNCTIONS
  
  defp wait_for_tendermint_start(tendermint_out) do
    wait_for_start(tendermint_out, "Started node", 20000)
  end
  
  defp wait_for_tm_bench_start(tm_bench_out) do
    wait_for_start(tm_bench_out, "Running ", 100)
  end
  
  defp wait_for_start(outstream, look_for, timeout) do
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

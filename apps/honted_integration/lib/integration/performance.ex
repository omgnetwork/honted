defmodule HonteD.Integration.Performance do
  @moduledoc """
  Tooling to run HonteD performance tests - orchestration and running tests
  """

  alias HonteD.Integration

  require Logger
  alias HonteD.{API}

  @doc """
  Starts a tm-bench Porcelain process for `duration_T` to listen for events and collect metrics
  """
  def tm_bench(duration_T) do
    # start the benchmarking tool and capture the stdout
    tm_bench_proc = %Porcelain.Process{err: nil, out: tm_bench_out} = Porcelain.spawn_shell(
      "tm-bench -c 0 -T #{duration_T} localhost:46657",
      out: :stream,
    )
    :ok = wait_for_tm_bench_start(tm_bench_out)

    {tm_bench_proc, tm_bench_out}
  end

  defp wait_for_tm_bench_start(tm_bench_out) do
    Integration.wait_for_start(tm_bench_out, "Running ", 1000)
  end

  defp check_result({:ok, _}, true), do: :ok
  defp check_result({:error, _}, false), do: :ok

  # will submit a stream of transactions to HonteD.API, checking expected result
  defp submit_stream(stream) do
    stream
    |> Enum.map(fn {expected, tx} ->
      tx
      |> HonteD.API.submit_sync()
      |> check_result(expected)
    end)
  end

  @doc """
  Fills the state a bit using txs source
  """
  def fill_in(txs_source, fill_in_per_stream) do
    fill_tasks = for txs_stream <- txs_source, do: Task.async(fn ->
      txs_stream
      |> Stream.take(fill_in_per_stream)
      |> submit_stream
    end)

    for task <- fill_tasks, do: Task.await(task, 100_000)
  end

  @doc """
  Runs the actual perf test scenario under tm-bench
  """
  def run_performance_test(txs_source, durationT) do
    _ = Logger.info("starting tm-bench")
    {tm_bench_proc, tm_bench_out} = tm_bench(durationT)

    for stream <- txs_source, do: _ = Task.async(fn ->
      stream
      |> submit_stream()
    end)

    # NOTE: absolutely no clue why we match like that, tm_bench_proc should run here
    {:error, :noproc} = Porcelain.Process.await(tm_bench_proc, durationT * 1000 + 1000)

    tm_bench_out
    |> Enum.to_list
    |> Enum.join
  end

  @doc """
  Assumes a setup done earlier, builds the scenario and runs performance test
   - nstreams: number of streams (processes) sending transactions
   - fill_in: number of transactions to pre-fill the state prior to perfornamce test
   - duration: time to run performance test under tm-bench [seconds]
  """
  def run(nstreams, fill_in, duration) do
    _ = Logger.info("Generating scenarios...")
    scenario = HonteD.Performance.Scenario.new(nstreams, nstreams * 2)
    _ = Logger.info("Starting setup...")
    setup_tasks = for setup_stream <- HonteD.Performance.Scenario.get_setup(scenario), do: Task.async(fn ->
          for {_, tx} <- setup_stream, do: API.submit_commit(tx)
        end)
    _ = Logger.info("Waiting for setup to complete...")
    for task <- setup_tasks, do: Task.await(task, 100_000)
    _ = Logger.info("Setup completed")

    txs_source = scenario.send_txs

    fill_in_per_stream = div(fill_in, nstreams)
    _ = Logger.info("Starting fill_in: #{inspect fill_in}")
    _ = txs_source
    |> fill_in(fill_in_per_stream)
    _ = Logger.info("Fill_in done")

    txs_source
    |> Enum.map(fn stream -> Stream.drop(stream, fill_in_per_stream) end)
    |> run_performance_test(duration)
  end

  @doc """
  Runs full HonteD node and runs perf test
  """
  def setup_and_run(nstreams, fill_in, duration) do
    dir_path = Integration.homedir()
    {:ok, _exit_fn} = Integration.honted()
    {:ok, _exit_fn} = Integration.tendermint(dir_path)
    run(nstreams, fill_in, duration)
  end
end

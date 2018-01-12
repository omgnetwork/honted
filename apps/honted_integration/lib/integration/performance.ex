defmodule HonteD.Integration.Performance do
  @moduledoc """
  Tooling to run HonteD performance tests - orchestration and running tests
  """

  alias HonteD.Integration
  alias HonteD.Performance

  require Logger
  alias HonteD.{API}
  import ExProf.Macro

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
  defp submit_stream(stream, opts \\ %{}) do
    stream
    |> Enum.map(fn {expected, tx} ->
      submit_one(expected, tx, opts)
    end)
  end
  defp submit_one(expected, tx, _) do
    tx
    |> HonteD.API.submit_sync()
    |> check_result(expected)
  end

  @doc """
  Fills the state a bit using txs source
  """
  defp fill_in(txs_source, fill_in_per_stream) do
    fill_tasks = for txs_stream <- txs_source, do: Task.async(fn ->
      txs_stream
      |> Stream.take(fill_in_per_stream)
      |> submit_stream
    end)

    for task <- fill_tasks, do: Task.await(task, 100_000)
  end

  @doc """
  Runs the actual perf test scenario under tm-bench.

  Assumes tm-bench is started. This is the protion of the test that should be measured/profiled etc
  """
  defp run_performance_test_tasks(txs_source, opts) do
    # begin test by starting asynchronous transaction senders
    for stream <- txs_source, do: Task.async(fn ->
      stream
      |> submit_stream(opts)
    end)
  end

  defp profilable_section(txs_source_without_fill_in, tm_bench_proc, duration, opts) do
    test_tasks =
      txs_source_without_fill_in
      |> run_performance_test_tasks(opts)

    # wait till end of test
    # NOTE: absolutely no clue why we match like that, tm_bench_proc should run here
    {:error, :noproc} = Porcelain.Process.await(tm_bench_proc, duration * 1000 + 1000)

    # cleanup
    for task <- test_tasks, do: nil = Task.shutdown(task, :brutal_kill)
  end

  @doc """
  Assumes a setup done earlier, builds the scenario and runs performance test
   - nstreams: number of streams (processes) sending transactions
   - fill_in: number of transactions to pre-fill the state prior to perfornamce test
   - duration: time to run performance test under tm-bench [seconds]
   - opts: options. Possibilities: %{bc_mode: nil | :commit}. Set to :commit to use submit_commit
     instead of submit_sync in load phase of performance test
  """
  def run(nstreams, fill_in, duration, %{profiling: profiling} = opts) do
    _ = Logger.info("Generating scenarios...")
    scenario = Performance.Scenario.new(nstreams, 10_000_000_000_000_000_000) # huge number of receivers
    _ = Logger.info("Starting setup...")
    setup_tasks = for setup_stream <- Performance.Scenario.get_setup(scenario), do: Task.async(fn ->
          for {true, tx} <- setup_stream, do: {:ok, _} = API.submit_sync(tx)
        end)
    _ = Logger.info("Waiting for setup to complete...")
    for task <- setup_tasks, do: Task.await(task, 100_000)
    _ = Logger.info("Setup completed")

    txs_source = Performance.Scenario.get_send_txs(scenario)

    fill_in_per_stream = div(fill_in, nstreams)

    _ = Logger.info("Starting fill_in: #{inspect fill_in}")
    txs_source
    |> fill_in(fill_in_per_stream)

    _ = Logger.info("Fill_in done")
    txs_source_without_fill_in = Performance.Scenario.get_send_txs(scenario, fill_in_per_stream)

    _ = Logger.info("starting tm-bench")
    {tm_bench_proc, tm_bench_out} = tm_bench(duration)

    case profiling do
      nil ->
        profilable_section(txs_source_without_fill_in, tm_bench_proc, duration, opts)
      :eprof ->
        profile do
          profilable_section(txs_source_without_fill_in, tm_bench_proc, duration, opts)
        end
      :eflame ->
        :eflame.apply(fn ->
          profilable_section(txs_source_without_fill_in, tm_bench_proc, duration, opts)
        end, [])
      :fprof ->
        :fprof.apply(fn ->
          profilable_section(txs_source_without_fill_in, tm_bench_proc, duration, opts)
        end, [], [procs: [:all]])
        :fprof.profile()

        [callers: true,
         sort: :own,
         totals: true,
         details: true]
        |> :fprof.analyse()
        |> IO.puts
    end

    tm_bench_out
    |> Enum.to_list
    |> Enum.join
  end

  @doc """
  Runs full HonteD node and runs perf test
  """
  def setup_and_run(nstreams, fill_in, duration, opts \\ %{profiling: nil}) do
    [:porcelain, :hackney]
    |> Enum.each(&Application.ensure_all_started/1)

    dir_path = Integration.homedir()
    {:ok, _exit_fn_honted} = Integration.honted()
    {:ok, exit_fn_tendermint} = Integration.tendermint(dir_path)

    result = run(nstreams, fill_in, duration, opts)

    exit_fn_tendermint.()

    # TODO: don't know why this is needed, should happen automatically on terminate. Does something bork at teardown?
    Temp.cleanup()

    IO.puts(result)
  end
end

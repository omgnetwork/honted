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
  defp submit_stream(stream) do
    stream
    |> Enum.map(fn {expected, tx} ->
      submit_one(expected, tx)
    end)
  end
  defp submit_one(expected, tx) do
    tx
    |> HonteD.API.submit_sync()
    |> check_result(expected)
  end

  # Fills the state a bit using txs source
  defp fill_in(txs_source, fill_in_per_stream) do
    fill_tasks = for txs_stream <- txs_source, do: Task.async(fn ->
      txs_stream
      |> Stream.take(fill_in_per_stream)
      |> submit_stream
    end)

    for task <- fill_tasks, do: Task.await(task, 100_000)
  end

  # Runs the actual perf test scenario under tm-bench.
  # Assumes tm-bench is started. This is the protion of the test that should be measured/profiled etc
  defp run_performance_test_tasks(txs_source) do
    # begin test by starting asynchronous transaction senders
    for stream <- txs_source, do: Task.async(fn ->
      stream
      |> submit_stream()
    end)
  end

  defp profilable_section(txs_source_without_fill_in, tm_bench_proc, duration) do
    test_tasks =
      txs_source_without_fill_in
      |> run_performance_test_tasks()

    # wait till end of test
    # NOTE: absolutely no clue why we match like that, tm_bench_proc should run here
    {:error, :noproc} = Porcelain.Process.await(tm_bench_proc, duration * 1000 + 1000)

    # cleanup
    for task <- test_tasks, do: nil = Task.shutdown(task, :brutal_kill)
  end

  defp wait_for_eep_convert(file_name) do
    callgrind_path = "callgrind.out.#{file_name}"
    Process.sleep(1000)
    if File.exists?(callgrind_path), do: :ok, else: wait_for_eep_convert(file_name)
  end

  @doc """
  Assumes a setup done earlier, builds the scenario and runs performance test
   - nstreams: number of streams (processes) sending transactions
   - fill_in: number of transactions to pre-fill the state prior to perfornamce test
   - duration: time to run performance test under tm-bench [seconds]
   - opts: options
  """
  def run(nstreams, fill_in, duration, opts) do
    profiling = opts[:profiling]

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

    fill_in_per_stream = if nstreams != 0, do: div(fill_in, nstreams), else: 0

    _ = Logger.info("Starting fill_in: #{inspect fill_in}")
    txs_source
    |> fill_in(fill_in_per_stream)

    _ = Logger.info("Fill_in done")
    txs_source_without_fill_in = Performance.Scenario.get_send_txs(scenario, skip_per_stream: fill_in_per_stream)

    _ = Logger.info("starting tm-bench")
    {tm_bench_proc, tm_bench_out} = tm_bench(duration)

    case profiling do
      nil ->
        profilable_section(txs_source_without_fill_in, tm_bench_proc, duration)
      :eep ->
        file_name = "eep_out"
        # profiling
        :eep.start_file_tracing(file_name |> to_charlist)
        profilable_section(txs_source_without_fill_in, tm_bench_proc, duration)
        :eep.stop_tracing()

        # conversion to kcachegrind format, need the wait, since eep converts async and provides no way to syncronise
        :eep.convert_tracing(file_name |> to_charlist)
        wait_for_eep_convert(file_name)
      :eprof ->
        profile do
          profilable_section(txs_source_without_fill_in, tm_bench_proc, duration)
        end
      :fprof ->
        :fprof.apply(fn ->
          profilable_section(txs_source_without_fill_in, tm_bench_proc, duration)
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
    |> finalize_tm_bench_output
  end

  defp finalize_tm_bench_output(tm_bench_out) do
    tm_bench_out
    |> Enum.to_list
    |> Enum.join
  end
end

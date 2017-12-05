defmodule HonteD.Integration.Performance do
  @moduledoc """
  Tooling to run HonteD performance tests - orchestration and running tests
  """

  alias HonteD.Integration
  
  require Logger
  alias HonteD.{Crypto, API}
   
  def tm_bench(duration_T) do
    # start tendermint and capture the stdout
    tm_bench_proc = %Porcelain.Process{err: nil, out: tm_bench_out} = Porcelain.spawn_shell(
      "tm-bench -c 0 -T #{duration_T} localhost:46657",
      out: :stream,
    )
    :ok = wait_for_tm_bench_start(tm_bench_out)
    
    {tm_bench_proc, tm_bench_out}
  end
  
  defp wait_for_tm_bench_start(tm_bench_out) do
    Integration.wait_for_start(tm_bench_out, "Running ", 100)
  end
  
  def dummy_txs_source(nstreams) do
    for _stream_id <- 1..nstreams do
      0
      |> Stream.interval
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
      
    for task <- fill_tasks, do: Task.await(task, 100_000)
  end
  
  def run_performance_test(txs_source, durationT) do
    _ = Logger.info("starting tm-bench")
    {tm_bench_proc, tm_bench_out} = tm_bench(durationT)
    
    for txs_stream <- txs_source, do: Task.async(fn ->
      txs_stream
      |> Enum.each(fn tx -> API.submit_transaction_async(tx) end)
    end)
    
    Porcelain.Process.await(tm_bench_proc, durationT * 1000 + 1000)
    
    tm_bench_out
    |> Enum.to_list
    |> Enum.join
  end
  
  def run(nstreams, fill_in, duration) do
    {homedir, homedir_exit_fn} = Integration.homedir()
    try do
      {:ok, _exit_fn} = Integration.honted()
      {:ok, _exit_fn} = Integration.tendermint(homedir)
      txs_source = dummy_txs_source(nstreams)

      txs_source
      |> fill_in(div(fill_in, nstreams))


      txs_source
      |> run_performance_test(duration)
    after
      homedir_exit_fn.()
    end
  end
end

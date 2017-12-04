defmodule HonteD.Integration.PerformanceTest do
  @moduledoc """
  """
  
  use ExUnitFixtures
  use ExUnit.Case, async: false
  
  require Logger
  
  alias HonteD.{Crypto, API}
  
  @moduletag :performance
  @moduletag :integration
  
  @moduletag timeout: :infinity
  
  @startup_timeout 100
  @await_fill_timeout 100000
  @duration 10
  @await_result_timeout @duration * 1000 + 1000
  
  @nstreams 10
  @fill_in 2000
  @fill_in_per_stream div(@fill_in, @nstreams)
  
  deffixture tm_bench(tendermint) do
    :ok = tendermint
    fn ->
      # start tendermint and capture the stdout
      tm_bench_proc = %Porcelain.Process{err: nil, out: tm_bench_out} = Porcelain.spawn_shell(
        "tm-bench -c 0 -T #{@duration} localhost:46657",
        out: :stream,
      )
      :ok = wait_for_tm_bench_start(tm_bench_out)
      
      {tm_bench_proc, tm_bench_out}
    end
  end
  
  defp wait_for_tm_bench_start(tm_bench_out) do
    HonteD.Integration.Fixtures.wait_for_start(tm_bench_out, "Running ", @startup_timeout)
  end
  
  deffixture txs_source() do
    # dummy txs_source for now, as many create_token transaction as possible
    for stream_id <- 1..@nstreams do
      Stream.interval(0)
      |> Stream.map(fn tx_id -> IO.puts("stream: #{stream_id}, tx: #{tx_id}"); tx_id end)
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
  
  deffixture fill_in(tendermint, txs_source) do
    :ok = tendermint
    # fill the state a bit
    fill_tasks = for txs_stream <- txs_source, do: Task.async(fn ->
      txs_stream
      |> Stream.take(@fill_in_per_stream)
      |> Enum.map(fn tx -> API.submit_transaction_async(tx) end)
    end)
      
    for task <- fill_tasks, do: Task.await(task, @await_fill_timeout)
  end
  
  @tag fixtures: [:tendermint, :tm_bench, :txs_source, :fill_in]
  test "send transaction performance", %{tm_bench: tm_bench_starter, txs_source: txs_source} do
    _ = Logger.info("starting tm-bench")
    {tm_bench_proc, tm_bench_out} = tm_bench_starter.()
    
    for txs_stream <- txs_source, do: Task.async(fn ->
      txs_stream
      |> Enum.map(fn tx -> API.submit_transaction_async(tx) end)
    end)
    
    Porcelain.Process.await(tm_bench_proc, @await_result_timeout)
    
    tm_bench_out
    |> Enum.to_list
    |> IO.puts
  end
end

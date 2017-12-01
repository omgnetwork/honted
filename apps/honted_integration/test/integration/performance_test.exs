defmodule HonteD.Integration.PerformanceTest do
  @moduledoc """
  """
  
  use ExUnitFixtures
  use ExUnit.Case, async: false
  
  alias HonteD.{Crypto, API}
  
  @moduletag :performance
  @moduletag :integration
  
  @moduletag timeout: :infinity
  
  @startup_timeout 100
  @await_result_timeout 11000
  
  deffixture tm_bench_starter(tendermint) do
    :ok = tendermint
    fn ->
      # start tendermint and capture the stdout
      tm_bench = %Porcelain.Process{err: nil, out: tm_bench_out} = Porcelain.spawn_shell(
        "tm-bench -c 0 localhost:46657",
        out: :stream,
      )
      :ok = wait_for_tm_bench_start(tm_bench_out)
      
      {tm_bench, tm_bench_out}
    end
  end
  
  defp wait_for_tm_bench_start(tm_bench_out) do
    HonteD.Integration.Fixtures.wait_for_start(tm_bench_out, "Running ", @startup_timeout)
  end
  
  @tag fixtures: [:tendermint, :tm_bench_starter]
  test "send transaction performance", %{tm_bench_starter: tm_bench_starter} do
    # FIXME: remove, just smoke testing the 
    txs = 
      Stream.interval(0)
      |> Stream.map(&IO.inspect/1)
      |> Stream.map(fn _ -> 
        {:ok, issuer_priv} = Crypto.generate_private_key()
        {:ok, issuer_pub} = Crypto.generate_public_key(issuer_priv)
        {:ok, issuer} = Crypto.generate_address(issuer_pub)
        {:ok, raw_tx} = HonteD.Transaction.create_create_token(nonce: 0, issuer: issuer)
        {:ok, signature} = Crypto.sign(raw_tx, issuer_priv)
        raw_tx <> " " <> signature
      end)
      
    # fill the state a bit
    txs
    |> Stream.take(30000)
    |> Enum.map(fn tx -> API.submit_transaction_async(tx) end)

    _ = Logger.info("starting tm-bench")
    {tm_bench, tm_bench_out} = tm_bench_starter.()
    
    Task.async(fn ->
      txs
      |> Enum.map(fn tx -> API.submit_transaction_async(tx) end)
    end)
    
    Porcelain.Process.await(tm_bench, @await_result_timeout)
    
    tm_bench_out
    |> Enum.to_list
    |> IO.puts
  end
end

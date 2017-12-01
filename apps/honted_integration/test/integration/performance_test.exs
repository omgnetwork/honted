defmodule HonteD.Integration.PerformanceTest do
  @moduledoc """
  """
  
  use ExUnitFixtures
  use ExUnit.Case, async: false
  
  alias HonteD.{Crypto, API}
  
  @moduletag :performance
  @moduletag :integration
  
  @startup_timeout 100
  @await_result_timeout 11000
  
  deffixture tm_bench(tendermint) do
    :ok = tendermint
    # start tendermint and capture the stdout
    tm_bench = %Porcelain.Process{err: nil, out: tm_bench_out} = Porcelain.spawn_shell(
      "tm-bench -c 0 localhost:46657",
      out: :stream,
    )
    :ok = wait_for_tm_bench_start(tm_bench_out)
      
    on_exit fn -> 
      Porcelain.Process.stop(tm_bench)
    end
    
    {tm_bench, tm_bench_out}
  end
  
  defp wait_for_tm_bench_start(tm_bench_out) do
    HonteD.Integration.Fixtures.wait_for_start(tm_bench_out, "Running ", @startup_timeout)
  end
  
  @tag fixtures: [:tendermint, :tm_bench]
  test "send transaction performance", %{tm_bench: {tm_bench, tm_bench_out}} do
    # FIXME: remove, just smoke testing the fixtures
    {:ok, issuer_priv} = Crypto.generate_private_key()
    {:ok, issuer_pub} = Crypto.generate_public_key(issuer_priv)
    {:ok, issuer} = Crypto.generate_address(issuer_pub)
    {:ok, raw_tx} = API.create_create_token_transaction(issuer)
    {:ok, signature} = Crypto.sign(raw_tx, issuer_priv)
    API.submit_transaction(raw_tx <> " " <> signature)
    
    Porcelain.Process.await(tm_bench, @await_result_timeout)
    
    tm_bench_out
    |> Enum.to_list
    |> IO.inspect
  end
end

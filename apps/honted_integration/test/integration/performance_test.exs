defmodule HonteD.Integration.PerformanceTest do
  @moduledoc """
  """
  
  use ExUnitFixtures
  use ExUnit.Case, async: false
  
  alias HonteD.Integration
  
  @moduletag :integration
  
  @moduletag timeout: :infinity
  
  @duration 3 # so that at least one block gets mined :)
  
  @nstreams 2
  @fill_in 200
  
  deffixture txs_source() do
    # dummy txs_source for now, as many create_token transaction as possible
    Integration.dummy_txs_source(@nstreams)
  end
  
  deffixture fill_in(tendermint, txs_source) do
    :ok = tendermint
    
    txs_source
    |> Integration.fill_in(div(@fill_in, @nstreams))
  end
  
  @tag fixtures: [:tendermint, :txs_source, :fill_in]
  test "send transaction performance", %{txs_source: txs_source} do
    txs_source
    |> Integration.run_performance_test(@duration)
    |> Enum.to_list
    |> IO.puts
  end
end

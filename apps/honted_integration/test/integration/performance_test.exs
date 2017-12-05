defmodule HonteD.Integration.PerformanceTest do
  @moduledoc """
  This is an integration test of the performance testing device
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias HonteD.Integration.Performance

  @moduletag :integration

  @moduletag timeout: :infinity

  @duration 3 # so that at least one block gets mined :)

  @nstreams 2
  @fill_in 200

  deffixture txs_source() do
    # dummy txs_source for now, as many create_token transaction as possible
    Performance.dummy_txs_source(@nstreams)
  end

  @tag fixtures: [:tendermint, :txs_source]
  test "performance test should run with fill in", %{txs_source: txs_source} do
    txs_source
    |> Performance.fill_in(div(@fill_in, @nstreams))

    txs_source
    |> Performance.run_performance_test(@duration)
    |> String.contains?("Txs/sec")
    |> assert
  end
end

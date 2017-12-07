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

  @nstreams 100
  @fill_in 200

  @tag fixtures: [:tendermint]
  test "performance test should run with fill in", %{} do
    result = Performance.run(@nstreams, @fill_in, @duration)

    result
    |> String.contains?("Txs/sec")
    |> assert
  end
end

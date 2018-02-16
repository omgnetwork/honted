defmodule HonteD.ABCI.Ethereum.EthashCacheServerTest do
  @moduledoc """
  Tests that generating Ethash cache works
  """
  # credo:disable-for-this-file Credo.Check.Readability.LargeNumbers
  use ExUnitFixtures
  use ExUnit.Case

  @moduletag :slow

  @epoch_length 30000

  alias HonteD.ABCI.Ethereum.EthashCacheServer

  describe "get_cache" do
    @tag timeout: 600000
    test "returns a cache", %{} do
      block_number = 10000
      expected_cache_line =
        [868643959, 3179556070, 1871292480, 2635187316, 2658670881, 3651954940, 864296532, 4161655205,
         1170742362, 1613380156, 3420562092, 2441378987, 2714353747, 536405404, 2918860778, 540860293]
      EthashCacheServer.start(block_number)

      {:ok, cache} = EthashCacheServer.get_cache(block_number)
      assert Enum.at(cache, 100) == expected_cache_line

      {:ok, cache} = EthashCacheServer.get_cache(block_number + 1000) # block in the same epoch
      assert Enum.at(cache, 100) == expected_cache_line

      :missing_cache = EthashCacheServer.get_cache(block_number + @epoch_length)
    end
  end

end

defmodule HonteD.ABCI.EthashCacheTest do
  @moduledoc """
  Tests if generating Ethash cache works
  """
  use ExUnitFixtures
  use ExUnit.Case

  alias HonteD.ABCI.EthashCache

  describe "make_cache" do
    @tag timeout: 960000
    test "returns a cache", %{} do
      assert Enum.at(EthashCache.make_cache(10000), 100) ==
        [868643959, 3179556070, 1871292480, 2635187316, 2658670881, 3651954940, 864296532, 4161655205,
         1170742362, 1613380156, 3420562092, 2441378987, 2714353747, 536405404, 2918860778, 540860293]
    end
  end

end

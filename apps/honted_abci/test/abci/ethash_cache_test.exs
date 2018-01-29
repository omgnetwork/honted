defmodule HonteD.ABCI.EthashCacheTest do
  @moduledoc """
  Tests if EthashUtils methods work
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias HonteD.ABCI.EthashCache

  describe "get_seed" do
    test "generates a cache seed hash", %{} do
      assert EthashCache.get_seed(20) ==
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
      assert EthashCache.get_seed(600000) ==
        <<74, 92, 105, 242, 92, 47, 154, 169, 14, 71, 108, 134, 176, 166, 122, 249, 138,
          19, 212, 182, 159, 231, 3, 100, 50, 185, 101, 19, 45, 52, 10, 118>>
    end
  end

  describe "cache_size" do
    test "returns cache size", %{} do
      assert EthashCache.cache_size(200) == 16776896
    end
  end

  describe "make_cache" do
    test "returns cache", %{} do
      assert hd(EthashCache.make_cache(
        16776896,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>)
        ) ==
        [1983793502, 1351496097, 3882638465, 1430409337, 3142489650, 1207557304, 2837420312,
         934227624, 2363919717, 2282225318, 3657689220, 2862884410, 1745502806, 2597186407,
         144437936, 3985622225]
    end
  end

end

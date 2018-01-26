defmodule HonteD.ABCI.EthashUtilsTest do
  @moduledoc """
  Tests if EthashUtils methods work
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  describe "encode_int" do
    test "should encode integer to 4 bytes little-endian", %{} do
      assert HonteD.ABCI.EthashUtils.encode_int(0) == <<0, 0, 0, 0>>
      assert HonteD.ABCI.EthashUtils.encode_int(16) == <<16, 0, 0, 0>>
      assert HonteD.ABCI.EthashUtils.encode_int(256) == <<0, 1, 0, 0>>
      assert HonteD.ABCI.EthashUtils.encode_int(21) == <<21, 0, 0, 0>>
    end
  end

  describe "decode_int" do
    test "should decode integer from little-endian bytes", %{} do
      assert HonteD.ABCI.EthashUtils.decode_int(<<0, 0, 0, 0>>) == 0
      assert HonteD.ABCI.EthashUtils.decode_int(<<16, 0, 0, 0>>) == 16
      assert HonteD.ABCI.EthashUtils.decode_int(<<0, 1, 0, 0>>) == 256
      assert HonteD.ABCI.EthashUtils.decode_int(<<21, 0, 0, 0>>) == 21
    end
  end

  describe "decode_ints" do
    test "should decode integers from little-endian bytes", %{} do
      assert HonteD.ABCI.EthashUtils.decode_ints(<<0, 0, 0, 0, 16, 0, 0, 0>>) == [0, 16]
      assert HonteD.ABCI.EthashUtils.decode_ints(<<16, 0, 0, 0, 0, 1, 0, 0>>) == [16, 256]
    end
  end

  #FIXME: compare to python code
  describe "keccak_512" do
    test "should hash a sequence of integer words", %{} do
      assert HonteD.ABCI.EthashUtils.keccak_512([16, 256, 1]) ==
        [2269139167, 3897159479, 4213387448, 3504581780, 1288272935,
         2775254355, 3273081633, 853482856, 2940421591, 3828985304,
         2278120504, 261390982, 2276026766, 3438532193, 3746780328,
         3500543143]
    end
  end

  describe "keccak_256" do
    test "should hash a sequence of integer words", %{} do
      assert HonteD.ABCI.EthashUtils.keccak_256([16, 256, 1]) ==
        [1078393248, 3535385300, 3909179523, 2017348610, 4078200048,
         350350202, 1825318387, 3469975711]
    end
  end

end

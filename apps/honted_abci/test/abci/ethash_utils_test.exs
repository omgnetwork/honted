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

  describe "hash_words" do
    test "should hash a sequence of integer words", %{} do
      assert HonteD.ABCI.EthashUtils.hash_words([16, 256, 1]) ==
        ""
    end
end

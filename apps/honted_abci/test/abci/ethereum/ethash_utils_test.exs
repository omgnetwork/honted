defmodule HonteD.ABCI.Ethereum.EthashUtilsTest do
  @moduledoc """
  Tests if EthashUtils methods work
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias HonteD.ABCI.Ethereum.EthashUtils

  describe "encode_int" do
    test "should encode integer to 4 bytes little-endian", %{} do
      assert EthashUtils.encode_int(0) == <<0, 0, 0, 0>>
      assert EthashUtils.encode_int(16) == <<16, 0, 0, 0>>
      assert EthashUtils.encode_int(255) == <<255, 0, 0, 0>>
      assert EthashUtils.encode_int(256) == <<0, 1, 0, 0>>
      assert EthashUtils.encode_int(21) == <<21, 0, 0, 0>>
    end
  end

  describe "encode_ints" do
    test "should encode integers to a sequence of bytes", %{} do
      assert EthashUtils.encode_ints([16, 256, 1]) ==
         <<16, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0>>
     assert EthashUtils.encode_ints([11, 1000, 23]) ==
        <<11, 0, 0, 0, 232, 3, 0, 0, 23, 0, 0, 0>>
    end
  end

  describe "decode_int" do
    test "should decode integer from little-endian bytes", %{} do
      assert EthashUtils.decode_int(<<0, 0, 0, 0>>) == 0
      assert EthashUtils.decode_int(<<16, 0, 0, 0>>) == 16
      assert EthashUtils.decode_int(<<0, 1, 0, 0>>) == 256
      assert EthashUtils.decode_int(<<21, 0, 0, 0>>) == 21
    end
  end

  describe "decode_ints" do
    test "should decode integers from little-endian bytes", %{} do
      assert EthashUtils.decode_ints(<<0, 0, 0, 0, 16, 0, 0, 0>>) == [0, 16]
      assert EthashUtils.decode_ints(<<16, 0, 0, 0, 0, 1, 0, 0>>) == [16, 256]
    end
  end

  describe "keccak_512" do
    test "should hash a sequence of integer words", %{} do
      assert EthashUtils.keccak_512([16, 256, 1]) ==
        [4065365687, 453237192, 1905149372, 2953961249, 2597321328, 2077506670,
         3635976784, 3891859941, 1233083118, 2890041799, 1411005159, 2953811025,
         1281490401, 3854921315, 155809664, 4044480253]
      assert EthashUtils.keccak_512([1011, 24, 110, 60000]) ==
        [778116395, 3567229325, 2886771786, 2660223114, 2714805707, 375593035,
         2247748593, 1397283925, 2265082138, 3849944674, 3755261755, 1154089301,
         157027831, 1754955909, 127637550, 2388340870]
    end
  end

  describe "keccak_256" do
    test "should hash a sequence of integer words", %{} do
      assert EthashUtils.keccak_256([16, 256, 1]) ==
        [4203686522, 703149359, 3718577756, 2811097105, 558933727, 2494295956, 803982374, 3619974695]
      assert EthashUtils.keccak_256(
      [4066991178, 2845454172, 2255243022, 4185564848, 3067351946, 1677977503, 325433650, 1980380205]) ==
        [1193997517, 3036238565, 1255408107, 86731387, 128040831, 4249366799, 2056486798, 3254615873]
      assert EthashUtils.keccak_256(<<1, 15, 1, 6, 255>>) ==
        [1296145895, 4278167019, 3873131276, 4163048277, 3028263632, 3334620915, 43564784, 1122983243]
    end
  end

  describe "prime?" do
    test "returns true for prime numbers", %{} do
      assert EthashUtils.prime?(5) == true
      assert EthashUtils.prime?(2) == true
      assert EthashUtils.prime?(67) == true
      assert EthashUtils.prime?(15485867) == true
    end

    test "returns false from composite numbers", %{} do
      assert EthashUtils.prime?(3 * 3) == false
      assert EthashUtils.prime?(1) == false
      assert EthashUtils.prime?(2 * 100) == false
      assert EthashUtils.prime?(15485867 * 15487313) == false
    end
  end

  describe "big_endian_to_int" do
    test "converts big endian bytes to in", %{} do
      assert EthashUtils.big_endian_to_int(<<0, 1, 16, 241, 144>>) == 17887632
    end
  end

  describe "hash_to_bytes" do
    test "converts hash to bytes", %{} do
      assert EthashUtils.hex_to_bytes("ac2d") == <<172, 45>>
      assert EthashUtils.hex_to_bytes("1eefe3932cc6281323cba77e2f2866cebd2b134083e86c235b88f900bf04ccf1") ==
        <<30, 239, 227, 147, 44, 198, 40, 19, 35, 203, 167, 126, 47, 40,
          102, 206, 189, 43, 19, 64, 131, 232, 108, 35, 91, 136, 249, 0,
          191, 4, 204, 241>>
    end
  end

end

defmodule HonteD.ABCI.Ethereum.BlockHeaderEncoderTest do
  @moduledoc """
  Tests if Events are processed correctly, by the registered :honted_events app

  THis tests only the integration between ABCI and the Eventer GenServer, i.e. whether the events are emitted
  correctly. No HonteD.API.Events logic tested here
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias HonteD.ABCI.Ethereum.EthashUtils
  alias HonteD.ABCI.Ethereum.BlockHeader
  alias HonteD.ABCI.Ethereum.BlockHeaderEncoder

  describe "header encoder" do
    test "encodes block header without nonce and mix hash", %{} do
      h_p = EthashUtils.hex_to_bytes("48a3455ef3d7ec9de0c3c13b3a2c190a097374822d63e0288003ad8c6849ff90")
      h_o = EthashUtils.hex_to_bytes("1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347")
      h_c = EthashUtils.hex_to_bytes("829bd824b016326a401d083b33d092293333a830")
      h_r = EthashUtils.hex_to_bytes("270a116d155bbee24e661995770ae2e38624f3f94ff213650798a5ebeaa9206d")
      h_t = EthashUtils.hex_to_bytes("411153e55666773e64b74c9e677c5ce33dcc0466e2c777e059c826ac5e62f415")
      h_e = EthashUtils.hex_to_bytes("291443b5954139bef5b2ae6eb109373ff9495866060f481d038dc85d4ac016cd")
      h_b = EthashUtils.hex_to_bytes("00000000040000020001000000420000801000000000000880800c00002000680000088000000000081002000400490208102440000000800040001000202100011040400800040100000009004010000020000000080801400100000309000040008020020020040040044000000850020002000024090000000111000800000000000000000008800000000000a1000000000000808084820008500400110002044000000000100000000050a0800400000900008084010002000000100001001000020004000800000000000000002000000500080004a01000000000200100100a2000000200000000400000808040201180000200201028029020000080")
      h_d = EthashUtils.hex_to_int("575806034c3cd")
      h_i = EthashUtils.hex_to_int("479c49")
      h_l = EthashUtils.hex_to_int("68af35")
      h_g = EthashUtils.hex_to_int("68679d")
      h_s = EthashUtils.hex_to_int("5a29b4d7")
      h_x = EthashUtils.hex_to_bytes("e4b883e5bda9e7a59ee4bb99e9b1bc") #TODO: is length of extra data even?
      block_header = %BlockHeader{
        parent_hash: h_p,
        ommers_hash: h_o,
        beneficiary: h_c,
        state_root: h_r,
        transactions_root: h_t,
        receipts_root: h_e,
        logs_bloom: h_b,
        difficulty: h_d,
        number: h_i,
        gas_limit: h_l,
        gas_used: h_g,
        timestamp: h_s,
        extra_data: h_x
      }

      assert BlockHeaderEncoder.pow_hash(block_header) ==
        <<109, 139, 200, 231, 34, 139, 212, 173, 82, 206, 238, 66, 48, 117,
          140, 115, 74, 133, 193, 190, 79, 56, 78, 162, 228, 252, 93, 117,
          81, 189, 187, 239>>
    end
  end
end

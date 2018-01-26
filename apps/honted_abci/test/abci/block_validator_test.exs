defmodule HonteD.ABCI.BlockValidationTest do
  @moduledoc """
  Tests if Events are processed correctly, by the registered :honted_events app

  THis tests only the integration between ABCI and the Eventer GenServer, i.e. whether the events are emitted
  correctly. No HonteD.API.Events logic tested here
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  describe "block validation" do
    test "validates a proper block", %{} do
      block_number = "0x4b9178"
      header_hash_no_nonce = "0x65a8cbf75da5d17c989a6583917037de24d43894b12e27992abd110f2138b16b"
      mix_hash = "0xf8c9b20b3eb622200ab9641c56dbd1efb2b0283a94bbf71b03e014d9623f40c6"
      nonce =  "0x8d163f100ca70a42"
      difficulty = "0x89187466cfb53"
      assert HonteD.ABCI.BlockValidation.valid?(block_number, header_hash_no_nonce, mix_hash, nonce, difficulty) == true
    end
  end
end

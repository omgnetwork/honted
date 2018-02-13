defmodule HonteD.ABCI.Ethereum.ProofOfWorkTest do
  @moduledoc """
  Tests if Events are processed correctly, by the registered :honted_events app

  THis tests only the integration between ABCI and the Eventer GenServer, i.e. whether the events are emitted
  correctly. No HonteD.API.Events logic tested here
  """
  use ExUnitFixtures
  use ExUnit.Case

  @moduletag :integration

  alias HonteD.ABCI.Ethereum.EthashUtils
  alias HonteD.ABCI.Ethereum.EthashCacheServer

  describe "header validation" do
    @tag timeout: 600_000
    test "validates a proper block", %{} do
      block_number = EthashUtils.hex_to_int("479c49")
      EthashCacheServer.start(block_number)

      header_hash_no_nonce =
        <<109, 139, 200, 231, 34, 139, 212, 173, 82, 206, 238, 66, 48, 117,
          140, 115, 74, 133, 193, 190, 79, 56, 78, 162, 228, 252, 93, 117,
          81, 189, 187, 239>>
      nonce = EthashUtils.hex_to_bytes("6cd7c4a814cddef9")
      mix_hash = EthashUtils.hex_to_bytes("1eefe3932cc6281323cba77e2f2866cebd2b134083e86c235b88f900bf04ccf1")
      difficulty = EthashUtils.hex_to_int("575806034c3cd")
      assert HonteD.ABCI.Ethereum.ProofOfWork.valid?(block_number, header_hash_no_nonce, mix_hash,
                                                     nonce, difficulty) == true
    end
  end
end

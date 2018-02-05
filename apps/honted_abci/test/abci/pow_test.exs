defmodule HonteD.ABCI.ProofOfWorkTest do
  @moduledoc """
  Tests if Events are processed correctly, by the registered :honted_events app

  THis tests only the integration between ABCI and the Eventer GenServer, i.e. whether the events are emitted
  correctly. No HonteD.API.Events logic tested here
  """
  use ExUnitFixtures
  use ExUnit.Case

  describe "header validation" do
    @tag timeout: 1200000
    test "validates a proper block", %{} do
      block_number = "479c49"
      header_hash_no_nonce =
        <<13, 153, 241, 180, 244, 61, 211, 250, 181, 99, 104, 155, 128, 250,
          97, 104, 229, 117, 93, 92, 246, 42, 207, 190, 241, 223, 156, 198,
          123, 98, 184, 15>>
      mix_hash = "1eefe3932cc6281323cba77e2f2866cebd2b134083e86c235b88f900bf04ccf1"
      nonce = "6cd7c4a814cddef9"
      difficulty = "575806034c3cd"
      assert HonteD.ABCI.ProofOfWork.valid?(block_number, header_hash_no_nonce, mix_hash, nonce, difficulty) == true
    end
  end
end

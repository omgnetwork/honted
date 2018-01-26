defmodule HonteD.ABCI.ProofOfWorkTest do
  @moduledoc """
  Tests if Events are processed correctly, by the registered :honted_events app

  THis tests only the integration between ABCI and the Eventer GenServer, i.e. whether the events are emitted
  correctly. No HonteD.API.Events logic tested here
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  describe "RLP encoder" do
    test "encodes block header without nonce and mix hash", %{} do
      assert [
        "ccc1fe96af9e0d436f5e943941c9291dd3dcc12b9a31e1806fecc843d09fcd4a",
        "1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
        "b2930b35844a230f00e51431acae96fe543a0347",
        "31f79beb235086472abfc7b30bb57f28a5b18788ed4e7cdb05f5cc702835fa95",
        "ce1d2d70170298a802554dc824be12c068e1b6f05153a6d55361e1288f73634a",
        "6c3213e46a86e7ad25f97fad626d1f29449d37e9c590db2e515e3d2f7cf1aed2",
        "4710004020445010240302a005404200000000014051009080110401082c017c00085201048521001080c33040400303000000000400180018400000442500410000805001200401c300109c800000004142100085a08000120100000002040000422a2c02010800e05000240008080800600022080440000000209100212004320400010044500240000048232008600000804081b0008410100000210220200214a0090104010880801000411c800080800c0360808020000083402091000000000412040c001008501900082000100505a08d002a000b021408082000a0010410008240a02091006000840044800440268600404820100001001281040081",
        "89187466cfb53",
        "4b9178",
        "7a11f8",
        "7a11a2",
        "5a65e3aa",
        "743139"
      ]
      |> ExRLP.encode
      |> ExthCrypto.Hash.Keccak.kec
      |> Base.encode16(case: :lower) == "a"
    end
  end
end

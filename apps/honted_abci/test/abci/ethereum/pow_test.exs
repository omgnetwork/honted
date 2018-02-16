defmodule HonteD.ABCI.Ethereum.ProofOfWorkTest do
  @moduledoc """
  Tests proof of work
  """
  use ExUnitFixtures
  use ExUnit.Case, async: false

  @moduletag :slow

  alias HonteD.ABCI.Ethereum.EthashUtils
  alias HonteD.ABCI.Ethereum.EthashCacheServer

  # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
  @max_difficulty 115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_936 # 2^256

  deffixture header, scope: :module do
     [
       block_number: EthashUtils.hex_to_int("479c49"),
       nonce: EthashUtils.hex_to_bytes("6cd7c4a814cddef9"),
       mix_hash: EthashUtils.hex_to_bytes("1eefe3932cc6281323cba77e2f2866cebd2b134083e86c235b88f900bf04ccf1"),
       hash_no_nonce:
         <<109, 139, 200, 231, 34, 139, 212, 173, 82, 206, 238, 66, 48, 117,
           140, 115, 74, 133, 193, 190, 79, 56, 78, 162, 228, 252, 93, 117,
           81, 189, 187, 239>>,
       difficulty: EthashUtils.hex_to_int("575806034c3cd")
     ]
  end

  deffixture cache(header), scope: :module do
    EthashCacheServer.start(header[:block_number])
  end

  describe "pow validation" do
    @tag fixtures: [:header]
    test "validates mined Ethereum block", %{header: header} do
      # Ethereum block number 4693065
      assert HonteD.ABCI.Ethereum.ProofOfWork.valid?(
        header[:block_number], header[:hash_no_nonce], header[:mix_hash],
        header[:nonce], header[:difficulty])
    end

    @tag fixtures: [:header]
    test "does not validate block with invalid nonce", %{header: header} do
      nonce = EthashUtils.hex_to_bytes("1ad7c4a814cddef9")
      refute HonteD.ABCI.Ethereum.ProofOfWork.valid?(
        header[:block_number], header[:hash_no_nonce], header[:mix_hash],
        nonce, header[:difficulty])
    end

    @tag fixtures: [:header]
    test "does not validate block with invalid mix hash", %{header: header} do
      mix_hash = EthashUtils.hex_to_bytes("2fefe3932cc6281323cba77e2f2866cebd2b134083e86c235b88f900bf04ccf1")
      refute HonteD.ABCI.Ethereum.ProofOfWork.valid?(
        header[:block_number], header[:hash_no_nonce], mix_hash,
        header[:nonce], header[:difficulty])
    end

    @tag fixtures: [:header]
    test "does not validate block when pow hash does not conform to difficulty", %{header: header} do
      hash_no_noce =
        <<148, 248, 238, 140, 149, 188, 29, 231, 216, 96, 61, 81, 204, 203, 151, 107,
          60, 202, 115, 102, 7, 220, 37, 1, 59, 214, 138, 145, 112, 248, 64, 120>> # header with max diffuculty
      refute HonteD.ABCI.Ethereum.ProofOfWork.valid?(
        header[:block_number], hash_no_noce, header[:mix_hash],
        header[:nonce], @max_difficulty)
    end
  end
end

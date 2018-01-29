defmodule HonteD.ABCI.ProofOfWork do
  @moduledoc """
  Validates proof of work for Ethereum block
  """
  @hash_length 32
  @nonce_length 8

  def valid?(block_number, header_hash, mix_hash, nonce, difficulty) do
    unless String.length(header_hash) == @hash_length and
      String.length(mix_hash) == @hash_length and
      String.length(nonce) == @nonce_length do
        cache = HonteD.ABCI.EthashCache.make_cache(block_number)
        full_size = HonteD.ABCI.EthashCache.full_size(block_number)
        {pow_hash, mix_digest} =
          HonteD.ABCI.Ethash.hashimoto_light(full_size, cache, header_hash, nonce)
        unless mix_digest == mix_hash do
          pow_hash <= div(HonteD.ABCI.EthashUtils.pow(2, 256), difficulty)
        else
          false
        end
      else
        false
      end
  end

end

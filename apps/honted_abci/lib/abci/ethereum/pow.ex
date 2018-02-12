defmodule HonteD.ABCI.Ethereum.ProofOfWork do
  @moduledoc """
  Validates proof of work for Ethereum block
  """
  alias HonteD.ABCI.Ethereum.EthashUtils

  @hash_length 32
  @nonce_length 8

  @dataset_bytes_init 1073741824 # 2^30
  @dataset_bytes_growth 8388608 # 2^17
  @mix_bytes 128
  @max_hash 115792089237316195423570985008687907853269984665640564039457584007913129639936 # 2^256
  @epoch_length 30000

  @doc """
  Returns true if proof of work for the block is valid, otherwise false.
  """
  @spec valid?(non_neg_integer(), binary(), binary(), binary(), non_neg_integer()) :: boolean()
  def valid?(block_number, header_hash, mix_hash, nonce, difficulty) do
    IO.puts(String.length(mix_hash))
    IO.puts(byte_size(header_hash))
    if byte_size(mix_hash) == @hash_length and byte_size(header_hash) == @hash_length and byte_size(nonce) == @nonce_length do
       IO.puts("in")
       cache = list_to_map(HonteD.ABCI.Ethereum.EthashCache.make_cache(block_number), 0, %{})
       IO.puts("cache calculated")
       full_size = full_dataset_size(block_number)

       [mix_digest: digest, result: pow_hash] =
         HonteD.ABCI.Ethereum.Ethash.hashimoto_light(full_size, cache, header_hash, nonce)
       if digest == mix_hash do
         EthashUtils.big_endian_to_int(pow_hash) <= div(@max_hash, difficulty)
       else
         false
       end
    else
      false
    end
  end

  def full_dataset_size(block_number) do
    initial = @dataset_bytes_init + @dataset_bytes_growth * div(block_number, @epoch_length) - @mix_bytes
    EthashUtils.e_prime(initial, @mix_bytes)
  end

  def list_to_map([], _idx, map), do: map
  def list_to_map([head | tail], idx, map) do
    list_to_map(tail, idx + 1, Map.put(map, idx, head))
  end

end

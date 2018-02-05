defmodule HonteD.ABCI.ProofOfWork do
  @moduledoc """
  Validates proof of work for Ethereum block
  """
  alias HonteD.ABCI.EthashUtils

  @hash_length_bytes 32
  @hash_length_hex 64
  @nonce_length 16

  @dataset_bytes_init 1073741824 # 2^30
  @dataset_bytes_growth 8388608 # 2^17
  @mix_bytes 128
  @max_hash 115792089237316195423570985008687907853269984665640564039457584007913129639936 # 2^256
  @epoch_length 30000

  def valid?(block_number, header_hash, mix_hash, nonce, difficulty) do
    IO.puts(String.length(mix_hash))
    IO.puts(byte_size(header_hash))
    IO.puts(String.length(nonce))
    if String.length(mix_hash) == 64 and byte_size(header_hash) == 32 and String.length(nonce) == 16 do
       IO.puts("in")
       {block_number, _} = Integer.parse(block_number, 16)
       {difficulty, _} = Integer.parse(difficulty, 16)
       mix_hash = EthashUtils.hash_to_bytes(mix_hash)
       cache = list_to_map(HonteD.ABCI.EthashCache.make_cache(block_number), 0, %{})
       IO.puts("cache calculated")
       full_size = full_dataset_size(block_number)

       [mix_digest: digest, result: pow_hash] =
         HonteD.ABCI.Ethash.hashimoto_light(full_size, cache, header_hash, nonce)
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

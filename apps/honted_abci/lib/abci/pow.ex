defmodule HonteD.ABCI.ProofOfWork do
  @moduledoc """
  Validates proof of work for Ethereum block
  """
  @hash_length 32
  @nonce_length 8

  @word_bytes 4
  @dataset_bytes_init 1073741824 # 2^30
  @dataset_bytes_growth 8388608 # 2^23
  @cache_bytes_init 16777216 # 2^24
  @cache_bytes_growth 131072 # 2^17
  @cache_multiplayer 1024
  @epoch_length 30000
  @mix_bytes 128
  @hash_bytes 64
  @dataset_parents 256
  @cache_rounds 3
  @accesses 64

  def valid?(block_number, header_hash, mix_hash, nonce, difficulty) do
    unless String.length(header_hash) == @hash_length and
      String.length(mix_hash) == @hash_length and
      String.length(nonce) == @nonce_length do
        cache = make_cache(block_number)
        {pow_hash, mix_digest} = {1, 1}#hoshimoto_light(block_number, cache, header_hash, nonce)
        unless mix_digest == mix_hash do
          pow_hash <= div(pow(2, 256), difficulty)
        else
          false
        end
      else
        false
      end
  end

  defp make_cache(block_number) do
    seed = get_seed(block_number)
    cache_size = cache_size(block_number) # already divided by HASH_BYTES
    seed = keccak_hex_512(seed)

    #implements RandMemoHash
    cache = [1..cache_size]
    |> List.foldl([seed], fn(_, acc) -> [keccak_hex_512(hd(acc)) | acc] end)
    |> Enum.reverse

    for _ <- [1..@cache_rounds],
        i <- [0..(cache_size - 1)] do
          v = cache
              |> Enum.fetch(i)
              |> String.first

        # cache[b] = :keccakf1600.sha3_512(cache[p] xor cache[j])
    end
  end

  defp keccak_hex_256(arg, keccak), do: Base.encode16(:keccakf1600.sha3_256(arg))
  defp keccak_hex_512(arg), do: Base.encode16(:keccakf1600.sha3_512(arg))

  defp as_integer(hex_char) do
    {int_value, _} = Integer.parse(hex_char, 16)
    int_value
  end

  defp cache_size(block_number) do
    size = @cache_bytes_init + @cache_bytes_growth * div(block_number, @epoch_length) - @hash_bytes
    get_cache_size(size)
  end

  defp get_cache_size(current_size) do
    if prime?(current_size) do
      current_size
    else
      get_cache_size(current_size - 2 * @mix_bytes)
    end
  end

  defp get_seed(block_number) do
    initial_seed =
      <<0>>
      |> List.duplicate(32)
      |> Enum.reduce(&<>/2)
    hash_rounds = div(block_number, @epoch_length)
    [1..hash_rounds]
    |> List.foldl(initial_seed, fn(_, seed) -> :keccakf1600.sha3_256(seed) end)
  end

  defp prime?(1), do: false
  defp prime?(num) when num > 1 and num < 4, do: true
  defp prime?(num) do
    upper_bound = round(Float.floor(:math.pow(num, 0.5)))
    [2..upper_bound]
    |> Enum.any(fn n -> rem(num, n) == 0 end)
  end

  defp pow(n, k), do: pow(n, k, 1)
  defp pow(_, 0, acc), do: acc
  defp pow(n, k, acc), do: pow(n, k - 1, n * acc)


end

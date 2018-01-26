defmodule HonteD.ABCI.Ethash do
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

  defp sha3_512(x) do
    hash_words()
  end

  defp hash_words(hash_f, x) when is_list(x) do
    serialize_hash(x)
    |> hash_f
    |> deserialize_hash
  end
  defp hash_words(hash_f, x) do
    hash_f(x)
    |> deserialize_hash
  end

  defp serialize_hash(h) do

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

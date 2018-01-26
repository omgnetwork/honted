defmodule HonteD.ABCI.Ethash do
  @moduledoc """
  Validates proof of work for Ethereum block
  """
  use Bitwise
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

  def make_cache(cache_size, seed) do
    n = div(cache_size, @hash_bytes)
    initial = initial_cache(n, seed)
    memo_hash_rounds(initial, 1, @cache_rounds)
  end

  defp memo_hash_rounds(cache, round_number, max_rounds) do
    if round_number > max_rounds do
      cache
    else
      memo_hash_rounds(memo_hash(cache, 1), round_number + 1, max_rounds)
    end
  end

  defp memo_hash(cache, i) do
    if i == length(cache) do
      cache
    else
      memo_hash(memo_hash_i(cache, i), i + 1)
    end
  end

  defp memo_hash_i(cache, i) do
    n = length(cache)
    v = cache
        |> Enum.at(i)
        |> Enum.at(0)
        |> rem(length(cache))
    j = rem(i - 1 + n, n)
    cache_i = Enum.zip(Enum.at(cache, j), Enum.at(cache, v))
              |> Enum.map(fn {a, b} -> a ^^^ b end)
    Enum.replace_at(cache, i, cache_i)
  end

  defp initial_cache(n, seed) when is_binary(seed) do
    initial_cache(n - 1, [HonteD.ABCI.EthashUtils.keccak_512(seed)])
  end
  defp initial_cache(0, acc) when is_list(acc), do: Enum.reverse(acc)
  defp initial_cache(n, acc) when is_list(acc) do
    [head | _] = acc
    initial_cache(n - 1, [HonteD.ABCI.EthashUtils.keccak_512(head) | acc])
  end

  defp cache_size(block_number) do
    size = @cache_bytes_init + @cache_bytes_growth * div(block_number, @epoch_length) - @hash_bytes
    get_cache_size(size)
  end

  defp get_cache_size(current_size) do
    if prime?(div(current_size, @mix_bytes)) do
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

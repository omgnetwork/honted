defmodule HonteD.ABCI.EthashCache do
  @moduledoc """
  Validates proof of work for Ethereum block
  """
  use Bitwise

  alias HonteD.ABCI.EthashUtils

  @cache_bytes_init 16777216 # 2^24
  @cache_bytes_growth 131072 # 2^17
  @epoch_length 30000
  @hash_bytes 64
  @cache_rounds 3

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
  defp initial_cache(1, acc) when is_list(acc), do: Enum.reverse(acc)
  defp initial_cache(n, acc) when is_list(acc) do
    [head | _] = acc
    initial_cache(n - 1, [HonteD.ABCI.EthashUtils.keccak_512(head) | acc])
  end

  def cache_size(block_number) do
    (@cache_bytes_init + @cache_bytes_growth * div(block_number, @epoch_length) - @hash_bytes)
    |> HonteD.ABCI.EthashUtils.e_prime(@hash_bytes)
  end

  def get_seed(block_number) do
    initial_seed =
      List.duplicate(<<0>>, 32)
      |> :binary.list_to_bin
    hash_rounds = div(block_number, @epoch_length)

    seed_loop(hash_rounds, initial_seed)
  end

  defp seed_loop(0, seed), do: seed
  defp seed_loop(n, seed), do: seed_loop(n - 1, :keccakf1600.sha3_256(seed))

end

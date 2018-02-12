defmodule HonteD.ABCI.Ethereum.Ethash do
  @moduledoc """
  Implements Ethash.
  """
  use Bitwise

  alias HonteD.ABCI.Ethereum.EthashUtils

  @fnv_prime 16777619
  @base_32 4294967296 # 2^32
  @hash_bytes 64
  @dataset_parents 256
  @dataset_mix_range 16 # @hash_bytes / @word_bytes
  @mix_hashes 2 # @mix_bytes / @hash_bytes
  @words 32 # @mix_bytes / @word_bytes
  @accesses 64

  defstruct [mix_digest: nil, result: nil]

  @type t :: %__MODULE__{mix_digest: <<_ :: 256>>, result: <<_ :: 256>>}

  @doc """
  Returns mix digest and hash result for given header and nonce
  """
  @spec hashimoto_light(integer(), list(list(non_neg_integer())), binary(), binary()) :: %__MODULE__{}
  def hashimoto_light(full_size, cache, header, nonce) do
    hashimoto(header, nonce, full_size, fn x -> calc_dataset_item(cache, x) end)
  end

  defp hashimoto(header, nonce, full_size, dataset_lookup) do
    n = div(full_size, @hash_bytes)
    nonce_le =
      :binary.bin_to_list(nonce)
      |> Enum.reverse
      |> :binary.list_to_bin

    seed = EthashUtils.keccak_512(header <> nonce_le)
    compressed_mix =
      seed
      |> List.duplicate(@mix_hashes)
      |> List.flatten
      |> mix_in_dataset(seed, dataset_lookup, n, 0)
      |> compress([])
    [mix_digest: EthashUtils.encode_ints(compressed_mix),
     result: EthashUtils.encode_ints(EthashUtils.keccak_256(seed ++ compressed_mix))]
  end

  defp mix_in_dataset(mix, _seed, _dataset_lookup, _n, @accesses), do: mix
  defp mix_in_dataset(mix, seed, dataset_lookup, n, round) do
    p = (fnv(round ^^^ Enum.at(seed, 0), Enum.at(mix, rem(round, @words)))
         |> rem(div(n, @mix_hashes))) * @mix_hashes
    new_data = get_new_data([], p, dataset_lookup, 0)
    mix = Enum.zip(mix, new_data)
          |> Enum.map(fn {a, b} -> fnv(a, b) end)
    mix_in_dataset(mix, seed, dataset_lookup, n, round + 1)
  end

  defp get_new_data(acc, _p, _dataset_lookup, @mix_hashes), do: Enum.reverse(acc)
  defp get_new_data(acc, p, dataset_lookup, round) do
    get_new_data(dataset_lookup.(p + round) ++ acc, p, dataset_lookup, round + 1)
  end

  defp compress([], compressed_mix), do: Enum.reverse(compressed_mix)
  defp compress(mix, compressed_mix) do
    [m1, m2, m3, m4 | tail] = mix
    c = fnv(m1, m2)
        |> fnv(m3)
        |> fnv(m4)
    compress(tail, [c | compressed_mix])
  end

  def calc_dataset_item(cache, i) do
    n = map_size(cache)
    [head | tail] = cache[rem(i, n)]
    initial = EthashUtils.keccak_512([head ^^^ i | tail])

    mix(cache, i, initial, 0)
    |> EthashUtils.keccak_512
  end

  defp mix(_cache, _i, current_mix, @dataset_parents), do: current_mix
  defp mix(cache, i, current_mix, round) do
    cache_index = fnv(i ^^^ round, Enum.at(current_mix, rem(round, @dataset_mix_range)))
    current_mix =
      Enum.zip(current_mix, cache[rem(cache_index, map_size(cache))])
      |> Enum.map(fn {a, b} -> fnv(a, b) end)
    mix(cache, i, current_mix, round + 1)
  end

  defp fnv(v1, v2) do
    rem((v1 * @fnv_prime) ^^^ v2, @base_32)
  end

end

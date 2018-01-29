defmodule HonteD.ABCI.EthashUtils do
  @moduledoc """
  Utility methods for Ethash. Implementation on Appendix section from Ethash wiki.
  """

  def encode_int(int), do: <<int :: little-32>>

  def decode_int(bytes_little_endian), do: :binary.decode_unsigned(bytes_little_endian, :little)

  def decode_ints(bytes), do: decode_ints_tr(bytes, [])

  defp decode_ints_tr(<<a, b, c, d>> <> tail, acc) do
    int = decode_int(<<a, b, c, d>>)
    decode_ints_tr(tail, [int | acc])
  end
  defp decode_ints_tr(<<>>, acc), do: Enum.reverse(acc)

  def keccak_512(ints) do
    hash(fn b -> :keccakf1600.sha3_512(b) end, ints)
  end

  defp hash(hash_f, ints) when is_list(ints) do
    encoded = encode_ints(ints)
    binary_hash = hash_f.(encoded)
    decode_ints(binary_hash)
  end
  defp hash(hash_f, binary) when is_binary(binary) do
    binary_hash = hash_f.(binary)
    decode_ints(binary_hash)
  end

  def encode_ints(ints) do
    ints
    |> Enum.map(&encode_int/1)
    |> Enum.reverse
    |> Enum.reduce(&<>/2)
  end

  def keccak_256(ints) do
    hash(fn b -> :keccakf1600.sha3_256(b) end, ints)
  end

  def pow(n, k), do: pow(n, k, 1)
  def pow(_, 0, acc), do: acc
  def pow(n, k, acc), do: pow(n, k - 1, n * acc)

  def e_prime(x, y) do
    if prime?(div(x, y)) do
      x
    else
      e_prime(x - 2 * y, y)
    end
  end

  def prime?(1), do: false
  def prime?(num) when num > 1 and num < 4, do: true
  def prime?(num) do
    upper_bound = round(Float.floor(:math.pow(num, 0.5)))
    2..upper_bound
    |> Enum.all?(fn n -> rem(num, n) != 0 end)
  end

end

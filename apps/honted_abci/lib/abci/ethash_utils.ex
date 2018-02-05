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

  def big_endian_to_int(big_endian_bytes) do
    big_endian_to_int(big_endian_bytes, 0)
  end
  defp big_endian_to_int(<<byte>>, acc), do: acc * 256 + byte
  defp big_endian_to_int(<<byte>> <> tail, acc) do
    big_endian_to_int(tail, 256 * acc + byte)
  end

  def hash_to_bytes(hash) do
    hash_to_bytes(hash, [])
  end
  defp hash_to_bytes("", acc) do
    Enum.reverse(acc)
    |> :binary.list_to_bin
  end
  defp hash_to_bytes(<<digit1 :: bytes-size(1)>> <> <<digit2 :: bytes-size(1)>> <> rest, acc) do
    {byte, _} = Integer.parse(digit1 <> digit2, 16)
    hash_to_bytes(rest, [byte | acc])
  end

end

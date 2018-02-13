defmodule HonteD.ABCI.Ethereum.EthashUtils do
  @moduledoc """
  Utility methods for Ethash. Implementation on Appendix section from Ethash wiki.
  """

  @doc """
  Encodes int as 8 bytes little-endian.
  """
  @spec encode_int(integer()) :: <<_ :: 8>>
  def encode_int(int), do: <<int :: little-32>>

  @doc """
  Decodes little-endian bytes to integer.
  """
  @spec decode_int(<<_ :: 4>>) :: non_neg_integer()
  def decode_int(bytes_little_endian), do: :binary.decode_unsigned(bytes_little_endian, :little)

  @doc """
  Decodes list of bytes to 4 bytes integers.
  """
  @spec decode_ints(binary()) :: list(non_neg_integer())
  def decode_ints(bytes), do: decode_ints_tr(bytes, [])

  defp decode_ints_tr(<<a, b, c, d>> <> tail, acc) do
    int = decode_int(<<a, b, c, d>>)
    decode_ints_tr(tail, [int | acc])
  end
  defp decode_ints_tr(<<>>, acc), do: Enum.reverse(acc)

  @doc """
  Returns keccak 512 hash of integer list encoded as 16 bytes integers.
  """
  @spec keccak_512(list(non_neg_integer())) :: list(non_neg_integer())
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

  @doc """
  Encodes list of integers into a sequence of bytes.
  """
  @spec encode_ints(list(non_neg_integer())) :: binary()
  def encode_ints(ints) do
    ints
    |> Enum.map(&encode_int/1)
    |> Enum.reverse
    |> Enum.reduce(&<>/2)
  end

  @doc """
  Returns keccak 256 hash of integer list encoded as 16 bytes integers.
  """
  @spec keccak_256(list(non_neg_integer())) :: list(non_neg_integer())
  def keccak_256(ints) do
    hash(fn b -> :keccakf1600.sha3_256(b) end, ints)
  end

  @doc """
  Returns n to power k.
  """
  @spec pow(integer(), non_neg_integer()) :: integer()
  def pow(n, k), do: pow(n, k, 1)
  def pow(_, 0, acc), do: acc
  def pow(n, k, acc), do: pow(n, k - 1, n * acc)

  @doc """
  Implements e_prime as in eq. 230 in yellowpaper Appendix J.
  """
  @spec pow(non_neg_integer(), non_neg_integer()) :: integer()
  def e_prime(x, y) do
    if prime?(div(x, y)) do
      x
    else
      e_prime(x - 2 * y, y)
    end
  end

  @doc """
  Returns true when argument is prime, otherwise false.
  """
  @spec prime?(non_neg_integer()) :: boolean()
  def prime?(1), do: false
  def prime?(num) when num > 1 and num < 4, do: true
  def prime?(num) do
    upper_bound = round(Float.floor(:math.pow(num, 0.5)))
    2..upper_bound
    |> Enum.all?(fn n -> rem(num, n) != 0 end)
  end

  @doc """
  Returns integer value for big-endian byte representation.
  """
  @spec big_endian_to_int(binary()) :: non_neg_integer()
  def big_endian_to_int(big_endian_bytes) do
    big_endian_to_int(big_endian_bytes, 0)
  end
  defp big_endian_to_int(<<byte>>, acc), do: acc * 256 + byte
  defp big_endian_to_int(<<byte>> <> tail, acc) do
    big_endian_to_int(tail, 256 * acc + byte)
  end

  @doc """
  Returns byte representation of a hex value.
  """
  @spec hex_to_bytes(String.t) :: binary()
  def hex_to_bytes(hex) do
    hex_to_bytes(hex, [])
  end
  defp hex_to_bytes("", acc), do: :binary.list_to_bin(Enum.reverse(acc))
  defp hex_to_bytes(<<digit1 :: bytes-size(1)>> <> <<digit2 :: bytes-size(1)>> <> rest, acc) do
    byte = hex_to_int(digit1 <> digit2)
    hex_to_bytes(rest, [byte | acc])
  end

  @doc """
  Returns integer value of a hex value.
  """
  @spec hex_to_int(String.t) :: non_neg_integer()
  def hex_to_int(hex) do
    {int, _} = Integer.parse(hex, 16)
    int
  end

end

defmodule HonteD.ABCI.EthashUtils do
  @moduledoc """
  Utility methods for Ethash
  """

  def encode_int(int), do: <<int :: little-32>>

  def decode_int(bytes_little_endian), do: :binary.decode_unsigned(bytes_little_endian, :little)

  def decode_ints(bytes), do: decode_ints_tr(bytes, [])

  defp decode_ints_tr(<<a, b, c, d>> <> tail, acc) do
    int = decode_int(<<a, b, c, d>>)
    decode_ints_tr(tail, [int | acc])
  end
  defp decode_ints_tr(<<>>, acc), do: Enum.reverse(acc)

end

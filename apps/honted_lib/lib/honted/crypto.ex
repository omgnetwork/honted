defmodule HonteD.Crypto do
  @moduledoc """
  Mock of a real cryptography API, to be replaced by Ethereum-compliant primitives
  """

  def hash(message), do: message |> erlang_hash |> Base.encode16

  # NOTE temporary function, which will go away when we move to sha3 and eth primitives
  defp erlang_hash(message), do: :crypto.hash(:sha256, message)

  @doc """
  Produce a stand-alone signature.
  """
  def signature(unsigned, priv) when is_binary(unsigned) do
    hash(unsigned <> priv <> "pub")
  end

  def verify(unsigned, signature, address), do: {:ok, hash(unsigned <> address) == signature}
  def generate_private_key, do: {:ok, :rand.uniform |> to_string |> hash |> Kernel.binary_part(0, 37)}
  def generate_public_key(priv), do: {:ok, priv <> "pub"}
  def generate_address(pub), do: {:ok, pub}
end

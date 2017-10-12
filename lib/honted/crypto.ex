defmodule HonteD.Crypto do
  @moduledoc """
  Mock of a real cryptography API, to be replaced by Ethereum-compliant primitives
  """
  
  def hash(message), do: :crypto.hash(:sha256, message) |> Base.encode16
  
  def sign(unsigned, priv), do: {:ok, hash(unsigned <> priv <> "pub")}
  def verify(unsigned, signature, address), do: {:ok, hash(unsigned <> address) == signature}
  def generate_private_key(), do: {:ok, :rand.uniform |> to_string |> hash |> String.slice(0,37)}
  def generate_public_key(priv), do: {:ok, priv <> "pub"}
  def generate_address(pub), do: {:ok, pub}
end

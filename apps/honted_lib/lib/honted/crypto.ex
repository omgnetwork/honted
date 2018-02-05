defmodule HonteD.Crypto do
  @moduledoc """
  Mock of a real cryptography API, to be replaced by Ethereum-compliant primitives
  """

  def hash(message), do: message |> erlang_hash |> Base.encode16

  # NOTE temporary function, which will go away when we move to sha3 and eth primitives
  defp erlang_hash(message), do: :crypto.hash(:sha256, message)

  @doc """
  Signs transaction, returns wire-encoded, hex-wrapped signed transaction.
  """
  @spec sign(binary, binary) :: binary
  def sign(tx, priv) when is_binary(tx) do
    {:ok, decoded} = tx |> Base.decode16!() |> HonteD.TxCodec.decode()
    sig = signature(decoded, priv)
    decoded
    |> HonteD.Transaction.with_signature(sig)
    |> HonteD.TxCodec.encode()
    |> Base.encode16()
  end

  @doc """
  Produce a stand-alone signature. Useful in tests.
  """
  def signature(unsigned, priv) when is_binary(unsigned) do
    hash(unsigned <> priv <> "pub")
  end
  def signature(%HonteD.Transaction.SignedTx{}, _) do
    raise ArgumentError, "Transaction already signed"
  end
  def signature(tx, priv) do
    tx
    |> HonteD.TxCodec.encode()
    |> signature(priv)
  end

  def verify(unsigned, signature, address), do: {:ok, hash(unsigned <> address) == signature}
  def generate_private_key, do: {:ok, :rand.uniform |> to_string |> hash |> Kernel.binary_part(0, 37)}
  def generate_public_key(priv), do: {:ok, priv <> "pub"}
  def generate_address(pub), do: {:ok, pub}
end

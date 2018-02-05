defmodule HonteD.TxCodecTest do
  use ExUnit.Case, async: true
  @moduledoc """
  """

  @moduletag :codec

  alias HonteD.Crypto

  test "encode for signed" do
    {:ok, priv} = Crypto.generate_private_key
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)

    {:ok, tx} = HonteD.Transaction.create_create_token(nonce: 1, issuer: address)
    tx
    |> HonteD.TxCodec.encode()
    |> Base.encode16()
    |> HonteD.Crypto.sign(priv)
  end

  test "encode/decode for unsigned" do
    {:ok, priv} = Crypto.generate_private_key
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)

    {:ok, tx} = HonteD.Transaction.create_create_token(nonce: 1, issuer: address)
    enc = HonteD.TxCodec.encode(tx)
    assert {:ok, ^tx} = HonteD.TxCodec.decode(enc)
  end

end

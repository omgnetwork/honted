defmodule HonteD.Token do
  @moduledoc """
  Library functions related to handling tokens' data
  """

  def create_address(issuer, nonce) when is_binary(issuer) and byte_size(issuer) == 40 do
    issuer
    |> HonteD.Crypto.hex_to_address!()
    |> create_address(nonce)
  end
  def create_address(issuer, nonce) when is_binary(issuer) and byte_size(issuer) == 20 do
    issuer
    |> Kernel.<>(" creates token number ")
    |> Kernel.<>(to_string(nonce))
    |> HonteD.Crypto.hash
    |> Kernel.binary_part(0, 20)
  end
end

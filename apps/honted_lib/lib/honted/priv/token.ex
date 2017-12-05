defmodule HonteD.Token do
  @moduledoc """
  Library functions related to handling tokens' data
  """
  def create_address(issuer, nonce) do
    issuer
    |> Kernel.<>(" creates token number ")
    |> Kernel.<>(to_string(nonce))
    |> HonteD.Crypto.hash
    |> Kernel.binary_part(0, 37)
    |> Kernel.<>("tok")
  end
end

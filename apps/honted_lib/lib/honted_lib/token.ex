defmodule HonteDLib.Token do
  def create_address(issuer, nonce) do
    issuer
    |> Kernel.<>(" creates token number ")
    |> Kernel.<>(to_string(nonce))
    |> HonteDLib.Crypto.hash
    |> Kernel.binary_part(0, 37)
    |> Kernel.<>("tok")
  end
end

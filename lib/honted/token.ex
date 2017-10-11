defmodule HonteD.Token do
  def create_address(issuer, nonce) do
    issuer |>
    Kernel.<>(" creates token number ") |>
    Kernel.<>(to_string(nonce)) |>
    HonteD.Crypto.hash |>
    String.slice(0,37) |>
    Kernel.<>("tok")
  end
end

defmodule HonteDLib.Transaction do
  defmodule CreateToken do
    defstruct [:nonce, :issuer]
    
  end
  
  defmodule Issue do
    defstruct [:nonce, :asset, :amount, :dest, :issuer]
    
  end
  
  defmodule Send do
    defstruct [:nonce, :asset, :amount, :from, :to]
    
  end
  
  defmodule SignedTx do
    defstruct [:raw_tx, :signature]
  end
  
  def with_signature(tx, signature) do
    %SignedTx{raw_tx: tx, signature: signature}
  end
  
  def create_create_token([nonce: nonce, issuer: issuer] = args)
  when is_integer(nonce) and
       is_binary(issuer) do
    create_encoded(CreateToken, args)
  end
  
  def create_issue([nonce: nonce, asset: asset, amount: amount, dest: dest, issuer: issuer] = args)
  when is_integer(nonce) and
       is_binary(asset) and
       is_integer(amount) and
       amount > 0 and
       is_binary(issuer) and
       is_binary(dest) do
    create_encoded(Issue, args)
  end
  
  def create_send([nonce: nonce, asset: asset, amount: amount, from: from, to: to] = args)
  when is_integer(nonce) and
       is_binary(asset) and
       is_integer(amount) and
       amount > 0 and
       is_binary(from) and
       is_binary(to) do
    create_encoded(Send, args)
  end
  
  def valid?(%CreateToken{}), do: :ok
  def valid?(%Issue{amount: amount}) when amount > 0, do: :ok
  def valid?(%Issue{}), do: {:error, :negative_amount}
  def valid?(%Send{amount: amount}) when amount > 0, do: :ok
  def valid?(%Send{}), do: {:error, :negative_amount}
  def valid?(%SignedTx{raw_tx: raw_tx, signature: _}) do
    with :ok <- valid?(raw_tx),
         # valid signature
         do: :ok
  end
  
  defp create_encoded(type, args) do
    with tx <- struct(type, args),
         :ok <- valid?(tx),
         do: {:ok, HonteDLib.TxCodec.encode(tx)}
  end
end

defmodule HonteDLib.Transaction do
  
  alias HonteDLib.Transaction.Validation
  
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
  
  defp create_encoded(type, args) do
    with tx <- struct(type, args),
         :ok <- Validation.valid?(tx),
         do: {:ok, HonteDLib.TxCodec.encode(tx)}
  end
end

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
  
  def valid?(%Issue{amount: amount}) do
    positive?(amount)
  end
  
  def valid?(%Send{amount: amount}) do
    positive?(amount)
  end
  
  def valid_signed?(%SignedTx{raw_tx: raw_tx, signature: signature}) do
    with :ok <- valid?(raw_tx),
         :ok <- signed?(HonteDLib.TxCodec.encode(raw_tx), signature, sender(raw_tx)),
         do: :ok
  end
  
  defp sender(%CreateToken{issuer: sender}), do: sender
  defp sender(%Issue{issuer: sender}), do: sender
  defp sender(%Send{from: sender}), do: sender
  
  defp positive?(amount) when amount > 0, do: :ok
  defp positive?(_), do: {:error, :positive_amount_required}

  defp signed?(signed_part, signature, src) do
    case HonteDLib.Crypto.verify(signed_part, signature, src) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :invalid_signature}
      _ -> {:error, :malformed_signature}
    end
  end
  
  defp create_encoded(type, args) do
    with tx <- struct(type, args),
         :ok <- valid?(tx),
         do: {:ok, HonteDLib.TxCodec.encode(tx)}
  end
end

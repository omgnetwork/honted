defmodule HonteDLib.Transaction.Validation do
  @moduledoc """
  Private plumbing of the Transaction module wrt. transaction validation
  """
  
  alias HonteDLib.Transaction.{CreateToken, Issue, Send, SignedTx}
  
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
  

end
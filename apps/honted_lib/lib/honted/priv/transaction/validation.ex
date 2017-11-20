defmodule HonteD.Transaction.Validation do
  @moduledoc """
  Private plumbing of the Transaction module wrt. transaction validation
  """
  
  alias HonteD.Transaction.{CreateToken, Issue, Send, SignOff, Allow, SignedTx}
  
  def valid?(%CreateToken{}), do: :ok
  
  def valid?(%Issue{amount: amount}) do
    positive?(amount)
  end
  
  def valid?(%Send{amount: amount}) do
    positive?(amount)
  end
  
  def valid?(%SignOff{height: height}) do
    positive?(height)
  end
  
  def valid?(%Allow{}), do: :ok
  
  def valid_signed?(%SignedTx{raw_tx: raw_tx, signature: signature}) do
    with :ok <- valid?(raw_tx),
         :ok <- signed?(raw_tx, signature),
         do: :ok
  end
  
  defp sender(%CreateToken{issuer: sender}), do: sender
  defp sender(%Issue{issuer: sender}), do: sender
  defp sender(%Send{from: sender}), do: sender
  defp sender(%SignOff{sender: sender}), do: sender
  defp sender(%Allow{allower: sender}), do: sender
  
  defp positive?(amount) when amount > 0, do: :ok
  defp positive?(_), do: {:error, :positive_amount_required}

  defp signed?(raw_tx, signature) do  
    raw_tx
    |> HonteD.TxCodec.encode
    |> HonteD.Crypto.verify(signature, sender(raw_tx))
    |> case do  # <3 this :)
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :invalid_signature}
      # NOTE: commented b/c dialyzer complains here, because Crypto.verify has degenerate returns for now
      # _ -> {:error, :malformed_signature}
    end
  end
  

end
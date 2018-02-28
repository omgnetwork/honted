defmodule HonteD.Transaction.Validation do
  @moduledoc """
  Private plumbing of the Transaction module wrt. transaction validation
  """

  alias HonteD.Transaction.{CreateToken, Issue, Unissue, Send, SignOff, Allow, EpochChange, SignedTx}

  def valid?(%CreateToken{}), do: :ok

  def valid?(%Issue{amount: amount}) do
    positive?(amount)
  end

  def valid?(%Unissue{amount: amount}) do
    positive?(amount)
  end

  def valid?(%Send{amount: amount}) do
    positive?(amount)
  end

  def valid?(%SignOff{height: height}) do
    positive?(height)
  end

  def valid?(%Allow{privilege: privilege}) do
    known?(privilege)
  end

  def valid?(%EpochChange{epoch_number: epoch_number}) do
    positive?(epoch_number)
  end

  @spec valid_signed?(HonteD.Transaction.t) :: :ok | {:error, atom}
  def valid_signed?(%SignedTx{raw_tx: raw_tx, signature: signature}) do
    with :ok <- valid?(raw_tx),
         :ok <- signed?(raw_tx, signature),
         do: :ok
  end
  def valid_signed?(unsigned_tx) when is_map(unsigned_tx) do
    {:error, :missing_signature}
  end

  def sender(%Send{from: sender}), do: sender
  def sender(%Allow{allower: sender}), do: sender
  def sender(%EpochChange{sender: sender}), do: sender
  def sender(%SignOff{sender: sender}), do: sender
  def sender(%Issue{issuer: sender}), do: sender
  def sender(%Unissue{issuer: sender}), do: sender
  def sender(%CreateToken{issuer: sender}), do: sender

  defp positive?(amount) when amount > 0, do: :ok
  defp positive?(_), do: {:error, :positive_amount_required}

  defp known?(privilege) when privilege in ["signoff"], do: :ok
  defp known?(_), do: {:error, :unknown_privilege}

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

#   Copyright 2018 OmiseGO Pte Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

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

defmodule HonteD.ABCI.Events do
  @moduledoc """
  Emitting of Events from the ABCI to an outside app handling events
  """

  @doc """
  Supply metadata for SignOff event - Eventer needs a list of tokens to
  be able to emit finalized events.
  """
  def notify(state, %HonteD.Transaction.SignedTx{raw_tx: %HonteD.Transaction.SignOff{} = tx} = signed) do
    case HonteD.ABCI.State.issued_tokens(state, tx.signoffer) do
      {:ok, tokens} ->
        HonteD.API.Events.notify(signed, tokens)
      nil ->
        HonteD.API.Events.notify(signed, [])
    end
  end
  def notify(_, tx) do
    HonteD.API.Events.notify_without_context(tx)
  end

end

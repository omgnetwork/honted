defmodule HonteD.ABCI.Events do
  @moduledoc """
  Supply metadata for SignOff event - Eventer needs a list of tokens to
  be able to emit finalized events.
  """

  def notify(state, %HonteD.Transaction.SignOff{} = tx) do
    case HonteD.ABCI.State.issued_tokens(state, tx.sender) do
      {:ok, tokens} ->
        HonteD.Events.notify(tx, tokens)
      nil ->
        HonteD.Events.notify(tx, [])
    end
  end
  def notify(_, tx) do
    HonteD.Events.notify(tx, [])
  end

end

defmodule HonteD.ABCI.Events do
  @moduledoc """
  Supply metadata for SignOff event - Eventer needs a list of tokens to
  be able to emit finalized events.
  """

  def notify(state, %HonteD.Transaction.SignOff{} = tx) do
    case HonteD.ABCI.issued_tokens(state, tx.sender) do
      {:ok, 0, value, _} ->
        HonteD.Events.notify(tx, value)
      {:error, _, _, _} ->
        HonteD.Events.notify(tx, [])
    end
  end
  def notify(_, tx) do
    HonteD.Events.notify(tx, [])
  end

end

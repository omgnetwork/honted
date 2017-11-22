defmodule HonteD.ABCI.Events do
  @moduledoc """
  Emitting of Events from the ABCI to an outside app handling events
  """

  @doc """
  Supply metadata for SignOff event - Eventer needs a list of tokens to
  be able to emit finalized events.
  """
  def notify(state, %HonteD.Transaction.SignOff{} = tx) do
    case HonteD.ABCI.State.issued_tokens(state, tx.sender) do
      {:ok, tokens} ->
        HonteD.API.Events.notify(tx, tokens)
      nil ->
        HonteD.API.Events.notify(tx, [])
    end
  end
  def notify(_, tx) do
    HonteD.API.Events.notify(tx, [])
  end

end

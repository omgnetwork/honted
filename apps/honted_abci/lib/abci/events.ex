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

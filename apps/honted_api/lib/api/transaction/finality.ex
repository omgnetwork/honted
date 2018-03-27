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

defmodule HonteD.API.Transaction.Finality do
  @moduledoc """
  Transaction finality logic.
  """

  @type event_height_pair :: {HonteD.block_height, HonteD.API.Events.event}
  @type event_queue :: Qex.t(event_height_pair) | Qex.t # not sure why empty Qex is needed here
  @type event_list :: [event_height_pair]

  @spec status(tx_height :: HonteD.block_height, HonteD.block_height, binary, binary)
    :: :finalized | :committed | :committed_unknown
  def status(tx_height, signed_off_height, signoff_hash, block_hash) do
    case {height_signed_off?(tx_height, signed_off_height),
          valid_signoff?(signoff_hash, block_hash)} do
      {true, true} -> :finalized
      {false, true} -> :committed
      {_, false} -> :committed_unknown
    end
  end

  @spec split_finalized_events(event_queue, HonteD.block_height)
    :: {event_list, event_queue}
  def split_finalized_events(queue, signed_off_height) do
    # for a given token will pop the events committed earlier, that are before the signed_off_height
    is_older = fn({h, _event}) -> height_signed_off?(h, signed_off_height) end

    {finalized_tuples, rest} =
      queue
      |> Enum.split_while(is_older)

    {finalized_tuples, Qex.new(rest)}
  end

  @spec valid_signoff?(HonteD.block_hash, HonteD.block_hash) :: boolean
  def valid_signoff?(signed_hash, real_block_hash), do: signed_hash == real_block_hash

  @spec height_signed_off?(HonteD.block_height, HonteD.block_height) :: boolean
  defp height_signed_off?(height, signed_off), do: height <= signed_off

end

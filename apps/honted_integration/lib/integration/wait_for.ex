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

defmodule HonteD.Integration.WaitFor do
  @moduledoc """
  Generic wait_for_* utils, styled after web3 counterparts
  """

  def eth_rpc do
    f = fn() ->
      case Ethereumex.HttpClient.eth_syncing() do
        {:ok, false} -> {:ok, :ready}
        _ -> :repeat
      end
    end
    fn() -> repeat_until_ok(f) end
    |> Task.async |> Task.await(10_000)
  end

  def eth_block_height(n, dev \\ false, timeout \\ 10_000) do
    f = fn() ->
      height = HonteD.Eth.Contract.block_height()
      case height < n do
        true ->
          _ = maybe_mine(dev)
          :repeat
        false ->
          {:ok, height}
      end
    end
    fn() -> repeat_until_ok(f) end
    |> Task.async |> Task.await(timeout)
  end

  def eth_receipt(txhash, timeout) do
    f = fn() ->
      case Ethereumex.HttpClient.eth_get_transaction_receipt(txhash) do
        {:ok, receipt} when receipt != nil -> {:ok, receipt}
        _ -> :repeat
      end
    end
    fn() -> repeat_until_ok(f) end
    |> Task.async |> Task.await(timeout)
  end

  def repeat_until_ok(f) do
    try do
      {:ok, _} = f.()
    catch
      _something ->
        Process.sleep(100)
        repeat_until_ok(f)
      :error, {:badmatch, _} = _error ->
        Process.sleep(100)
        repeat_until_ok(f)
    end
  end

  defp maybe_mine(false), do: :noop
  defp maybe_mine(true) do
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()
    txmap = %{from: addr, to: addr, value: "0x1"}
    {:ok, txhash} = Ethereumex.HttpClient.eth_send_transaction(txmap)
    {:ok, _receipt} = eth_receipt(txhash, 1_000)
  end
end

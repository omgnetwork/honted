defmodule HonteD.Eth.WaitFor do
  @moduledoc """
  Generic wait_for_* utils, styled after web3 counterparts
  """
  import Ethereumex.HttpClient

  def rpc() do
    f = fn() ->
      IO.puts("before eth_syncing")
      {:ok, false} = eth_syncing()
      IO.puts("after good eth_syncing")
      {:ok, :ready}
    end
    function(fn() -> repeat_until_ok(f) end, 10_000)
  end

  def receipt(txhash, timeout) do
    f = fn() ->
      case eth_get_transaction_receipt(txhash) do
        {:ok, receipt} when receipt != nil -> {:ok, receipt}
        _ -> :repeat
      end
    end
    rf = fn() -> repeat_until_ok(f) end
    function(rf, timeout)
  end

  def function(f, timeout) do
    f
    |> Task.async
    |> Task.await(timeout)
  end

  def repeat_until_ok(f) do
    try do
      {:ok, _} = f.()
    catch
      something ->
        IO.puts("repeat until single clause: #{inspect something}")
        Process.sleep(100)
        repeat_until_ok(f)
      :error, {:badmatch, _} = error ->
        IO.puts("repeat until double clause: #{inspect {:error, error}}")
        Process.sleep(100)
        repeat_until_ok(f)
    end
  end
end

defmodule HonteD.Eth.WaitFor do
  @moduledoc """
  Generic wait_for_* utils, styled after web3 counterparts
  """
  import Ethereumex.HttpClient

  def rpc() do
    f = fn() ->
      {:ok, false} = eth_syncing()
      {:ok, :ready}
    end
    function(fn() -> repeat_until_ok(f) end, 10_000)
  end

  def receipt(txhash, timeout) do
    f = fn() ->
      {:ok, receipt} = eth_get_transaction_receipt(txhash)
      true = receipt != nil
      {:ok, receipt}
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
      _ ->
        Process.sleep(100)
        repeat_until_ok(f)
      _, _ ->
      Process.sleep(100)
      repeat_until_ok(f)
    end
  end
end

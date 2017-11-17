defmodule HonteD.API.TestHelpers do

  def address1(), do: "address1"
  def address2(), do: "address2"

  def event_send(receiver, token \\ "asset") do
    # FIXME: how can I distantiate from the implementation details (like codec/encoding/creation) some more?
    # for now we use raw HonteD.Transaction structs, abandoned alternative is to go through encode/decode
    tx = %HonteD.Transaction.Send{nonce: 0, asset: token, amount: 1, from: "from_addr", to: receiver}
    {tx, receivable_for(tx)}
  end

  def event_sign_off(sender, send_receivables, height \\ 1) do
    tx = %HonteD.Transaction.SignOff{nonce: 0, height: height, hash: height2hash(height), sender: sender}
    {tx, receivable_finalized(send_receivables)}
  end

  def event_sign_off_bad_hash(sender, send_receivables, height \\ 1) do
    tx = %HonteD.Transaction.SignOff{nonce: 0, height: height, hash: "BADHASH", sender: sender}
    {tx, receivable_finalized(send_receivables)}
  end

  def height2hash(n) when is_integer(n) and n > 0 and n < 100, do: "OK_HASH_" <> Integer.to_string(n)
  def height2hash(_), do: nil

  @doc """
  Prepared based on documentation of HonteD.Events.notify
  """
  def receivable_for(%HonteD.Transaction.Send{} = tx) do
    {:event, %{source: :filter, type: :committed, transaction: tx}}
  end

  def receivable_finalized(list) when is_list(list) do
    for event <- list, do: receivable_finalized(event)
  end
  def receivable_finalized({:event, recv = %{type: :committed}}) do
    {:event, %{recv | type: :finalized}}
  end

  def join(pids) when is_list(pids) do
    for pid <- pids, do: join(pid)
  end
  def join(pid) when is_pid(pid) do
    ref = Process.monitor(pid)
    receive do
      {:DOWN, ^ref, :process, ^pid, _} ->
        :ok
    end
  end

  def join() do
    join(Process.get(:clients, []))
  end

  def client(fun) do
    pid = spawn_link(fun)
    Process.put(:clients, [pid | Process.get(:clients, [])])
    pid
  end

end

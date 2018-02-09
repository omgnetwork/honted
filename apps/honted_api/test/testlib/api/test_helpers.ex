defmodule HonteD.API.TestHelpers do
  @moduledoc """
  Varius shared functions for testing the API
  """

  def address1, do: "address1"
  def address2, do: "address2"

  def event_send(receiver, fid, token \\ "asset", height \\ 0) do
    # NOTE: how can I distantiate from the implementation details (like codec/encoding/creation) some more?
    # for now we use raw HonteD.Transaction structs, abandoned alternative is to go through encode/decode
    tx = %HonteD.Transaction.Send{nonce: 0, asset: token, amount: 1, from: "from_addr", to: receiver}
    signed = %HonteD.Transaction.SignedTx{raw_tx: tx, signature: "F47485AD4B907207D6D05B7265D6B91B47985BFB2C694C7A9AC20D83Dfakesig"}
    {signed, receivable_for(signed, fid, height)}
  end

  def event_sign_off(send_receivables, height \\ 1) do
    tx = %HonteD.Transaction.SignOff{nonce: 0, height: height, hash: height2hash(height)}
    signed = %HonteD.Transaction.SignedTx{raw_tx: tx, signature: "F47485AD4B907207D6D05B7265D6B91B47985BFB2C694C7A9AC20D83Dfakesig"}
    {signed, receivable_finalized(send_receivables)}
  end

  def event_sign_off_bad_hash(send_receivables, height \\ 1) do
    tx = %HonteD.Transaction.SignOff{nonce: 0, height: height, hash: "BADHASH"}
    {tx, receivable_finalized(send_receivables)}
  end

  def height2hash(n) when is_integer(n) and n > 0, do: "OK_HASH_" <> Integer.to_string(n)
  def height2hash(_), do: nil

  @doc """
  Prepared based on documentation of HonteD.API.Events.notify
  """
  def receivable_for(%HonteD.Transaction.SignedTx{raw_tx: %HonteD.Transaction.Send{} = tx} = signed, fid, height) do
    # FIXME: this hash is copy-pasted - what to do about this testing?
    event = %HonteD.API.Events.Eventer.TransactionEvent{tx: tx,
                                                        hash: signed
                                                              |> HonteD.TxCodec.encode
                                                              |> HonteD.API.Tendermint.Tx.hash}
    {:event, %{height: height, finality: :committed, source: fid, transaction: event}}
  end

  def receivable_finalized(list) when is_list(list) do
    for event <- list, do: receivable_finalized(event)
  end
  def receivable_finalized({:event, recv = %{finality: :committed}}) do
    {:event, %{recv | finality: :finalized}}
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

  def join do
    join(Process.get(:clients, []))
  end

  def client(fun) do
    pid = spawn_link(fun)
    Process.put(:clients, [pid | Process.get(:clients, [])])
    pid
  end

end

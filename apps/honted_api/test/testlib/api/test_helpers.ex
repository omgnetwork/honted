defmodule HonteD.API.TestHelpers do
  @moduledoc """
  Varius shared functions for testing the API
  """

  alias HonteD.Crypto

  def address1, do: "address1"
  def address2, do: "address2"

  def event_send(receiver, fid, token \\ "asset", height \\ 0) do
    # NOTE: how can I distantiate from the implementation details (like codec/encoding/creation) some more?
    # for now we use raw HonteD.Transaction structs, abandoned alternative is to go through encode/decode
    priv = "C8B804D5DE04A865FB1B8EE92632DC728B29B"
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, addr} = Crypto.generate_address(pub)
    signed =
      %HonteD.Transaction.Send{nonce: 0, asset: token, amount: 1, from: addr, to: receiver}
      |> sign_unpack(priv)

    {signed, receivable_for(signed, fid, height)}
  end

  defp sign_unpack(tx, priv) do
    tx
    |> HonteD.TxCodec.encode()
    |> Base.encode16()
    |> HonteD.Transaction.sign(priv)
    |> Base.decode16!()
    |> HonteD.TxCodec.decode!()
  end

  def event_sign_off(send_receivables, height \\ 1) do
    {:ok, priv} = Crypto.generate_private_key()
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, addr} = Crypto.generate_address(pub)
    signed =
      %HonteD.Transaction.SignOff{nonce: 0, height: height, sender: addr,
                                  signoffer: addr, hash: height2hash(height)}
      |> sign_unpack(priv)

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
    hash =
      signed
      |> HonteD.TxCodec.encode
      |> HonteD.API.Tendermint.Tx.hash
    event = %HonteD.API.Events.Eventer.EventContentTx{tx: tx, hash: hash}

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

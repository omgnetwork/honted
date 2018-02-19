defmodule HonteD.TxCodec do
  @moduledoc """
  Handles transforming correctly formed transactions to tuples and vice versa
  Encoded transactions are handled by Tendermint core.

  Uses RLP. This encoding is used as wire encoding for transactions.
  When Tx are transmitted in text, hex encoding is used as a wrapper
  (outside of scope of this module).
  """
  alias HonteD.Transaction

  @signature_length 64

  # true/false wire representation
  @byte_false <<64>>
  @byte_true <<65>>

  # tx type tags, wire representation
  @create_token <<1>>
  @issue <<2>>
  @send <<3>>
  @signoff <<4>>
  @allow <<5>>
  @epoch_change <<6>>

  @doc """
  Encodes internal representation of transaction into a Tendermint transaction

  Note that correctness of terms should be checked elsewhere
  """
  @spec encode(HonteD.Transaction.t()) :: binary
  def encode(tx) do
    tx
    |> to_value_list()
    |> _pack()
  end

  @doc """
  Decode transaction from form it was delivered by Tendermint to HonteD
  internal representation. Does type checking for fields.
  """
  @spec decode(binary) :: {:ok, HonteD.Transaction.t()} | {:error, atom}
  def decode(line) do
    with :ok <- valid_size?(line),
         {:ok, tx} <- rlp_decode(line),
         {:ok, tx, tail} <- reconstruct_tx(tx) do
      maybe_sig(tx, tail)
    end
  end

  def decode!(line) do
    {:ok, decoded} = decode(line)
    decoded
  end

  @doc """
  Returns wire representation for booleans and tx tags.
  """
  def tx_tag(Transaction.CreateToken), do: @create_token
  def tx_tag(Transaction.Issue), do: @issue
  def tx_tag(Transaction.Send), do: @send
  def tx_tag(Transaction.SignOff), do: @signoff
  def tx_tag(Transaction.Allow), do: @allow
  def tx_tag(Transaction.EpochChange), do: @epoch_change
  def tx_tag(true), do: @byte_true
  def tx_tag(false), do: @byte_false

  # private functions

  defp maybe_sig(tx, []), do: {:ok, tx}

  defp maybe_sig(tx, [sig]) do
    with :ok <- signature_length?(sig) do
      {:ok, Transaction.with_signature(tx, sig)}
    end
  end

  defp maybe_sig(_, _) do
    {:error, :malformed_transaction}
  end

  defp rlp_decode(line) do
    try do
      {:ok, ExRLP.decode(line)}
    catch
      _ ->
        {:error, :malformed_transaction_rlp}
    end
  end

  defp signature_length?(sig) when byte_size(sig) == @signature_length, do: :ok
  defp signature_length?(_sig), do: {:error, :bad_signature_length}

  # NOTE: find the correct and informed maximum valid transaction byte-size
  # and test that out properly (by trying out a maximal valid transaction possible - right now it only tests a 0.5KB tx)
  defp valid_size?(line) when byte_size(line) > 274 * 2, do: {:error, :transaction_too_large}
  defp valid_size?(_line), do: :ok

  defp int_parse(int), do: :binary.decode_unsigned(int, :big)

  defp reconstruct_tx(tx) do
    case tx do
      [@create_token, nonce, issuer | tail] ->
        {:ok, %Transaction.CreateToken{nonce: int_parse(nonce), issuer: issuer}, tail}

      [@issue, nonce, asset, amount, dest, issuer | tail] ->
        {:ok,
         %Transaction.Issue{
           nonce: int_parse(nonce),
           asset: asset,
           amount: int_parse(amount),
           dest: dest,
           issuer: issuer
         }, tail}

      [@send, nonce, asset, amount, from, to | tail] ->
        {:ok,
         %Transaction.Send{
           nonce: int_parse(nonce),
           asset: asset,
           amount: int_parse(amount),
           from: from,
           to: to
         }, tail}

      [@signoff, nonce, height, hash, sender, signoffer | tail] ->
        {:ok,
         %Transaction.SignOff{
           nonce: int_parse(nonce),
           height: int_parse(height),
           hash: hash,
           sender: sender,
           signoffer: signoffer
         }, tail}

      [@allow, nonce, allower, allowee, privilege, allow | tail]
      when allow in [@byte_true, @byte_false] ->
        {:ok,
         %Transaction.Allow{
           nonce: int_parse(nonce),
           allower: allower,
           allowee: allowee,
           privilege: privilege,
           allow: allow == @byte_true
         }, tail}

      [@epoch_change, nonce, sender, epoch_number | tail] ->
        {:ok,
         %Transaction.EpochChange{
           nonce: int_parse(nonce),
           sender: sender,
           epoch_number: int_parse(epoch_number)
         }, tail}

      _tx ->
        {:error, :malformed_transaction}
    end
  end

  def to_value_list(%Transaction.SignedTx{raw_tx: tx, signature: sig}) do
    to_value_list(tx) ++ [sig]
  end

  def to_value_list(tx) when is_map(tx) do
    keys = (tx.__struct__).f()
    map = Map.from_struct(tx)
    values = for key <- keys, do: Map.get(map, key)
    tag = tx_tag(tx.__struct__)
    [tag | values]
  end

  defp _pack(terms) do
    terms
    |> pre_rlp_encode()
    |> ExRLP.encode()
  end

  defp pre_rlp_encode(list) when is_list(list), do: list |> Enum.map(&pre_rlp_encode(&1))
  defp pre_rlp_encode(bool) when is_boolean(bool), do: tx_tag(bool)
  defp pre_rlp_encode(other), do: other
end

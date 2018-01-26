defmodule HonteD.TxCodec do
  @moduledoc """
  Handles transforming correctly formed transaction encodings to tuples and vice versa

  Encoded transactions are handled by Tendermint core
  """
  alias HonteD.Transaction

  @signature_length 64

  def decode(line) do
    with :ok <- valid_size?(line),
         do: do_decode(line)
  end

  # NOTE: find the correct and informed maximum valid transaction byte-size
  # and test that out properly (by trying out a maximal valid transaction possible - right now it only tests a 0.5KB tx)
  defp valid_size?(line) when byte_size(line) <= 274, do: :ok
  defp valid_size?(_line), do: {:error, :transaction_too_large}

  # NOTE: credo complains about CC here, but this is going away with RLP so why bother
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
  defp do_decode(line) do
    case String.split(line) do
      [nonce, "CREATE_TOKEN", issuer, signature] when byte_size(signature) == @signature_length ->
        case Integer.parse(nonce) do
          {int_nonce, ""} -> {:ok, %Transaction.CreateToken{nonce: int_nonce,
                                                            issuer: issuer}
                                   |> with_signature(signature)}
          _ -> {:error, :malformed_numbers}
        end
      [nonce, "ISSUE", asset, amount, dest, issuer, signature] when byte_size(signature) == @signature_length ->
        case {Integer.parse(amount), Integer.parse(nonce)} do
          {{int_amount, ""}, {int_nonce, ""}} -> {:ok, %Transaction.Issue{nonce: int_nonce,
                                                                          asset: asset,
                                                                          amount: int_amount,
                                                                          dest: dest,
                                                                          issuer: issuer}
                                                       |> with_signature(signature)}
          _ -> {:error, :malformed_numbers}
        end
      [nonce, "SEND", asset, amount, from, to, signature] when byte_size(signature) == @signature_length ->
        case {Integer.parse(amount), Integer.parse(nonce)} do
          {{int_amount, ""}, {int_nonce, ""}} -> {:ok, %Transaction.Send{nonce: int_nonce,
                                                                         asset: asset,
                                                                         amount: int_amount,
                                                                         from: from,
                                                                         to: to}
                                                       |> with_signature(signature)}
          _ -> {:error, :malformed_numbers}
        end
      [nonce, "SIGN_OFF", height, hash, sender, signoffer, signature] when byte_size(signature) == @signature_length ->
        case {Integer.parse(height), Integer.parse(nonce)} do
          {{int_height, ""}, {int_nonce, ""}} -> {:ok, %Transaction.SignOff{nonce: int_nonce,
                                                                            height: int_height,
                                                                            hash: hash,
                                                                            sender: sender,
                                                                            signoffer: signoffer}
                                                       |> with_signature(signature)}
          _ -> {:error, :malformed_numbers}
        end
      [nonce, "ALLOW", allower, allowee, privilege, allow, signature] when byte_size(signature) == @signature_length and
                                                                           allow in ["true", "false"] ->
        case Integer.parse(nonce) do
          {int_nonce, ""} -> {:ok, %Transaction.Allow{nonce: int_nonce,
                                                      allower: allower,
                                                      allowee: allowee,
                                                      privilege: privilege,
                                                      allow: allow == "true"}
                                                      |> with_signature(signature)}
          _ -> {:error, :malformed_numbers}
        end
      [nonce, "EPOCH_CHANGE", sender, epoch_number, signature] when byte_size(signature) == @signature_length ->
        case {Integer.parse(nonce), Integer.parse(epoch_number)} do
          {{int_nonce, ""}, {int_epoch_number, ""}} -> {:ok, %Transaction.EpochChange{nonce: int_nonce,
                                                      sender: sender,
                                                      epoch_number: int_epoch_number}
                                                      |> with_signature(signature)}
          _ -> {:error, :malformed_numbers}
        end
      _ -> {:error, :malformed_transaction}
    end
  end

  def decode!(line) do
    {:ok, decoded} = decode(line)
    decoded
  end

  @doc """
  Encodes a generic list of terms into a Tendermint transaction

  Note that correctness of terms should be checked elsewhere
  """
  def encode(%Transaction.CreateToken{nonce: nonce, issuer: issuer}) do
    {nonce, :create_token, issuer}
    |> _encode
  end
  def encode(%Transaction.Issue{nonce: nonce, asset: asset, amount: amount, dest: dest, issuer: issuer}) do
    {nonce, :issue, asset, amount, dest, issuer}
    |> _encode
  end
  def encode(%Transaction.Send{nonce: nonce, asset: asset, amount: amount, from: from, to: to}) do
    {nonce, :send, asset, amount, from, to}
    |> _encode
  end
  def encode(%Transaction.SignOff{nonce: nonce, height: height, hash: hash, sender: sender, signoffer: signoffer}) do
    {nonce, :sign_off, height, hash, sender, signoffer}
    |> _encode
  end
  def encode(%Transaction.Allow{nonce: nonce, allower: allower, allowee: allowee, privilege: privilege, allow: allow}) do
    {nonce, :allow, allower, allowee, privilege, allow}
    |> _encode
  end
  def encode(%Transaction.EpochChange{nonce: nonce, sender: sender, epoch_number: epoch_number}) do
    {nonce, :epoch_change, sender, epoch_number}
    |> _encode
  end

  defp _encode(terms) when is_tuple(terms), do: terms |> Tuple.to_list |> _encode
  defp _encode([last_term]), do: _encode(last_term)
  defp _encode([terms_head | terms_tail]) do
    _encode(terms_head) <> " " <> _encode(terms_tail)
  end

  defp _encode(term) when is_binary(term), do: term
  defp _encode(term) when is_boolean(term), do: to_string(term)
  defp _encode(term) when is_atom(term), do: String.upcase(to_string(term))
  defp _encode(term) when is_number(term), do: "#{term}"

  defp with_signature(tx, signature) do
    %Transaction.SignedTx{raw_tx: tx, signature: signature}
  end
end

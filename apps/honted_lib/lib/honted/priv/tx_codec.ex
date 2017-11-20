defmodule HonteD.TxCodec do
  @moduledoc """
  Handles transforming correctly formed transaction encodings to tuples and vice versa

  Encoded transactions are handled by Tendermint core
  """
  alias HonteD.Transaction

  def decode(line) do
    case String.split(line) do
      [nonce, "CREATE_TOKEN", issuer, signature] when byte_size(signature) == 64 ->
        case Integer.parse(nonce) do
          {int_nonce, ""} -> {:ok, %Transaction.CreateToken{nonce: int_nonce, 
                                                            issuer: issuer}
                                   |> with_signature(signature)}
          _ -> {:error, :malformed_numbers}
        end
      [nonce, "ISSUE", asset, amount, dest, issuer, signature] when byte_size(signature) == 64 ->
        case {Integer.parse(amount), Integer.parse(nonce)} do
          {{int_amount, ""}, {int_nonce, ""}} -> {:ok, %Transaction.Issue{nonce: int_nonce,
                                                                          asset: asset,
                                                                          amount: int_amount,
                                                                          dest: dest,
                                                                          issuer: issuer}
                                                       |> with_signature(signature)}
          _ -> {:error, :malformed_numbers}
        end
      [nonce, "SEND", asset, amount, from, to, signature] when byte_size(signature) == 64 ->
        case {Integer.parse(amount), Integer.parse(nonce)} do
          {{int_amount, ""}, {int_nonce, ""}} -> {:ok, %Transaction.Send{nonce: int_nonce,
                                                                         asset: asset,
                                                                         amount: int_amount,
                                                                         from: from,
                                                                         to: to}
                                                       |> with_signature(signature)}
          _ -> {:error, :malformed_numbers}
        end
      [nonce, "SIGN_OFF", height, hash, sender, signoffer, signature] when byte_size(signature) == 64 ->
        case {Integer.parse(height), Integer.parse(nonce)} do
          {{int_height, ""}, {int_nonce, ""}} -> {:ok, %Transaction.SignOff{nonce: int_nonce,
                                                                            height: int_height,
                                                                            hash: hash,
                                                                            sender: sender,
                                                                            signoffer: signoffer}
                                                       |> with_signature(signature)}
          _ -> {:error, :malformed_numbers}
        end
      [nonce, "ALLOW", allower, allowee, privilege, allow, signature] when byte_size(signature) == 64 ->
        case Integer.parse(nonce) do
          {int_nonce, ""} -> {:ok, %Transaction.Allow{nonce: int_nonce,
                                                      allower: allower,
                                                      allowee: allowee,
                                                      privilege: privilege,
                                                      allow: allow}
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
  
  defp _encode(terms) when is_tuple(terms), do: terms |> Tuple.to_list |> _encode
  defp _encode([last_term]), do: _encode(last_term)
  defp _encode([terms_head | terms_tail]) do
    _encode(terms_head) <> " " <> _encode(terms_tail)
  end

  defp _encode(term) when is_binary(term), do: term
  defp _encode(term) when is_atom(term), do: String.upcase(to_string(term))
  defp _encode(term) when is_number(term), do: "#{term}"
  
  defp with_signature(tx, signature) do
    %Transaction.SignedTx{raw_tx: tx, signature: signature}
  end
end

defmodule HonteD.TxCodec do
  @moduledoc """
  Handles transforming correctly formed transaction encodings to tuples and vice versa

  Encoded transactions are handled by Tendermint core
  """

  def decode(line) do
    case String.split(line) do
      [nonce, "ISSUE", asset, amount, dest, issuer, signature] ->
        case {Integer.parse(amount), Integer.parse(nonce)} do
          {{int_amount, ""}, {int_nonce, ""}} -> {:ok, {int_nonce, :issue, asset, int_amount, dest, issuer, signature}}
          _ -> {:error, :malformed_numbers}
        end
      [nonce, "SEND", asset, amount, from, to, signature] ->
        case {Integer.parse(amount), Integer.parse(nonce)} do
          {{int_amount, ""}, {int_nonce, ""}} -> {:ok, {int_nonce, :send, asset, int_amount, from, to, signature}}
          _ -> {:error, :malformed_numbers}
        end
      ["ORDER", buy_asset, sell_asset, buy_amount, price, initiate_at, ttl, buyer] ->
        case {Integer.parse(buy_amount), Float.parse(price)} do
          {{int_buy_amount, ""}, {float_price, ""}} ->
            {:ok, {:order, buy_asset, sell_asset, int_buy_amount, float_price, initiate_at, ttl, buyer}}
          _ ->
            {:error, :malformed_numbers}
        end
      _ -> {:error, :malformed_transaction}
    end
  end

  @doc """
  Encodes a generic list of terms into a Tendermint transaction

  Note that correctness of terms should be checked elsewhere
  """
  def encode(terms) when is_tuple(terms), do: terms |> Tuple.to_list |> encode
  def encode([last_term]), do: _encode(last_term)
  def encode([terms_head | terms_tail]) do
    _encode(terms_head) <> " " <> encode(terms_tail)
  end

  defp _encode(term) when is_binary(term), do: term
  defp _encode(term) when is_atom(term), do: String.upcase(to_string(term))
  defp _encode(term) when is_number(term), do: "#{term}"
end

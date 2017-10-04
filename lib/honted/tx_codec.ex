defmodule HonteD.TxCodec do
  @moduledoc """
  Handles transforming correctly formed transaction encodings to tuples and vice versa

  Encoded transactions are handled by Tendermint core
  """

  def decode(line) do
    case String.split(line) do
      ["ISSUE", asset, amount, dest] ->
        case Integer.parse(amount) do
          {int_amount, _} -> {:ok, {:issue, asset, int_amount, dest}}
          _ -> {:error, :malformed_amount}
        end
      ["SEND", asset, amount, from, to] ->
        case Integer.parse(amount) do
          {int_amount, _ } -> {:ok, {:send, asset, int_amount, from, to}}
          _ -> {:error, :malformed_amount}
        end
      ["ORDER", buy_asset, sell_asset, buy_amount, price, initiate_at, ttl, buyer] ->
        case {Integer.parse(buy_amount), Float.parse(price)} do
          {{int_buy_amount, _}, {float_price, _}} ->
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
  def encode([last_term]), do: _encode(last_term)
  def encode([terms_head | terms_tail]) do
    _encode(terms_head) <> " " <> encode(terms_tail)
  end

  defp _encode(term) when is_binary(term), do: term
  defp _encode(term) when is_atom(term), do: String.upcase(to_string(term))
  defp _encode(term) when is_number(term), do: "#{term}"
end

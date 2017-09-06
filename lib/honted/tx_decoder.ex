defmodule HonteD.TxDecoder do

  def decode(line) do
    case String.split(line) do
      ["ISSUE", asset, amount, dest] ->
        case Integer.parse(amount) do
          {int_amount, _} -> {:ok, {:mint, asset, int_amount, dest}}
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
end

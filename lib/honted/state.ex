defmodule HonteD.State do
  @moduledoc """
  Main workhorse of the `honted` ABCI app. Manages the state of the application replicated on the blockchain
  """

  @type t :: map()
  def empty(), do: %{}

  def exec(state, {:issue, asset, amount, dest}) do
    key = "accounts/#{asset}/#{dest}"
    state = Map.update(state, key, amount, &(&1 + amount))
    {:ok, state}
  end

  def exec(state, {:send, asset, amount, src, dest}) do
    key_src = "accounts/#{asset}/#{src}"
    key_dest = "accounts/#{asset}/#{dest}"
    balance_prior_src = Map.get(state, key_src, 0)
    if balance_prior_src < amount do
      {:error, state}
    else
      {:ok, state |> Map.put(key_src, balance_prior_src - amount)
                  |> Map.update(key_dest, amount, &(&1 + amount))}
    end

  end

  def exec(state, {:order, buy_asset, sell_asset, buy_amount, price, _initiate_at, _ttl, buyer}) do
    key_src = "accounts/#{sell_asset}/#{buyer}"
    key_order = "orders/#{buy_asset}/#{sell_asset}/#{buy_amount}/#{price}"
    sell_amount = round(buy_amount * price)
    balance_prior_src = Map.get(state, key_src, 0)
    if balance_prior_src < sell_amount do
      {:error, state}
    else
      state = Map.update!(state, key_src, &(&1 - sell_amount))
      key_insta_match = "orders/#{sell_asset}/#{buy_asset}/#{sell_amount}/#{1/price}"
      case Map.get(state, IO.inspect key_insta_match) do
        {:buyer, seller} ->
          {:ok, state |> Map.update("accounts/#{buy_asset}/#{buyer}", buy_amount, &(&1 + buy_amount))
                      |> Map.update("accounts/#{sell_asset}/#{seller}", sell_amount, &(&1 + sell_amount))
                      |> Map.delete(key_insta_match)}
        _ ->
          {:ok, Map.put(state, key_order, {:buyer, buyer})}
      end
    end
  end
end

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

  def exec(state, {nonce, :send, asset, amount, src, dest}) do
    key_src = "accounts/#{asset}/#{src}"
    key_dest = "accounts/#{asset}/#{dest}"
    if Map.get(state, key_src, 0) < amount or
       Map.get(state, "nonces/#{src}", 0) != nonce do
      {:error, state}
    else
      {:ok, state |> Map.update("nonces/#{src}", 1, &(&1 + 1))
                  |> Map.update!(key_src, &(&1 - amount))
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

  def hash(state) do
    # FIXME: crudest of all app state hashes
    state |>
    OJSON.encode! |>  # using OJSON instead of inspect to have crypto-ready determinism
    (fn b -> :crypto.hash(:sha256, b) end).() |>
    Base.encode16
  end
end

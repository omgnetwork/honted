defmodule HonteD.State do
  @moduledoc """
  Main workhorse of the `honted` ABCI app. Manages the state of the application replicated on the blockchain
  """
  
  @max_amount round(:math.pow(2,256))

  @type t :: map()
  def empty(), do: %{}

  def exec(state, {nonce, :create_token, issuer, signature}) do
    signed_part = 
      {nonce, :create_token, issuer} |>
      HonteD.TxCodec.encode
      
    with {:ok} <- nonce_valid?(state, issuer, nonce),
         {:ok} <- signed?(signed_part, signature, issuer),
         do: {:ok, state |> apply_create_token(issuer, nonce)}
  end

  def exec(state, {nonce, :issue, asset, amount, dest, issuer, signature}) do
    signed_part = 
      {nonce, :issue, asset, amount, dest, issuer} |>
      HonteD.TxCodec.encode
      
    with {:ok} <- not_too_much?(amount),
         {:ok} <- nonce_valid?(state, issuer, nonce),
         {:ok} <- is_issuer?(state, asset, issuer),
         {:ok} <- signed?(signed_part, signature, issuer),
         do: {:ok, state |> apply_issue(asset, amount, dest, issuer)}
  end

  def exec(state, {nonce, :send, asset, amount, src, dest, signature}) do
    key_src = "accounts/#{asset}/#{src}"
    key_dest = "accounts/#{asset}/#{dest}"
    signed_part = 
      {nonce, :send, asset, amount, src, dest} |>
      HonteD.TxCodec.encode

    with {:ok} <- positive?(amount),
         {:ok} <- nonce_valid?(state, src, nonce),
         {:ok} <- account_has_at_least?(state, key_src, amount),
         {:ok} <- signed?(signed_part, signature, src),
         do: {:ok, state |> apply_send(amount, src, key_src, key_dest)}

  end

  # FIXME: don't look at this, very very obsolete, for reference only
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
  
  defp positive?(amount) when amount > 0, do: {:ok}
  defp positive?(_), do: {:positive_amount_required}
  
  defp account_has_at_least?(state, key_src, amount) do
    if Map.get(state, key_src, 0) >= amount, do: {:ok}, else: {:insufficient_funds}
  end
  
  defp nonce_valid?(state, src, nonce) do
    if Map.get(state, "nonces/#{src}", 0) == nonce, do: {:ok}, else: {:invalid_nonce}
  end
  
  defp not_too_much?(amount_entering) do
    if amount_entering < @max_amount, do: {:ok}, else: {:amount_way_too_large}
  end
  
  defp is_issuer?(state, token_addr, address) do
    case Map.get(state, "tokens/#{token_addr}/issuer") do
      nil -> {:unknown_issuer}
      ^address -> {:ok}
      _ -> {:incorrect_issuer}
    end
  end
  
  defp apply_create_token(state, issuer, nonce) do
    token_addr = HonteD.Token.create_address(issuer, nonce)
    state |> 
    bump_nonce(issuer) |>
    Map.put("tokens/#{token_addr}/issuer", issuer)
  end
  
  defp apply_issue(state, asset, amount, dest, issuer) do
    key_dest = "accounts/#{asset}/#{dest}"
    state |> 
    bump_nonce(issuer) |>
    Map.update(key_dest, amount, &(&1 + amount))
  end
  
  defp apply_send(state, amount, src, key_src, key_dest) do
    state |>
    bump_nonce(src) |> 
    Map.update!(key_src, &(&1 - amount)) |>
    Map.update(key_dest, amount, &(&1 + amount))
  end
  
  defp bump_nonce(state, address) do
    state |> 
    Map.update("nonces/#{address}", 1, &(&1 + 1))
  end
  
  defp signed?(signed_part, signature, src) do
    case HonteD.Crypto.verify(signed_part, signature, src) do
      {:ok, true} -> {:ok}
      {:ok, false} -> {:invalid_signature}
      _ -> {:malformed_signature}
    end
  end

  def hash(state) do
    # FIXME: crudest of all app state hashes
    state |>
    OJSON.encode! |>  # using OJSON instead of inspect to have crypto-ready determinism
    HonteD.Crypto.hash
  end
end

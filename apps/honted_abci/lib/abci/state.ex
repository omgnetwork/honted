defmodule HonteD.ABCI.State do
  @moduledoc """
  Main workhorse of the `honted` ABCI app. Manages the state of the application replicated on the blockchain
  """
  alias HonteD.Transaction

  @max_amount round(:math.pow(2,256))  # used to limit integers handled on-chain

  def empty(), do: %{}

  def get(state, key) do
    case state[key] do
      nil -> nil
      value -> {:ok, value}
    end
  end

  def issued_tokens(state, address) do
    key = "issuers/" <> to_string(address)
    case get(state, key) do
      {:ok, value} ->
        {:ok, value |> scan_potential_issued(state, to_string(address))}
      nil ->
        nil
    end
  end

  def exec(state, %Transaction.SignedTx{raw_tx: %Transaction.CreateToken{} = tx}) do

    with :ok <- nonce_valid?(state, tx.issuer, tx.nonce),
         do: {:ok, state |> apply_create_token(tx.issuer, tx.nonce)}
  end

  def exec(state, %Transaction.SignedTx{raw_tx: %Transaction.Issue{} = tx}) do

    with :ok <- nonce_valid?(state, tx.issuer, tx.nonce),
         :ok <- is_issuer?(state, tx.asset, tx.issuer),
         :ok <- not_too_much?(state["tokens/#{tx.asset}/total_supply"] + tx.amount),
         do: {:ok, state |> apply_issue(tx.asset, tx.amount, tx.dest, tx.issuer)}
  end

  def exec(state, %Transaction.SignedTx{raw_tx: %Transaction.Send{} = tx}) do
    key_src = "accounts/#{tx.asset}/#{tx.from}"
    key_dest = "accounts/#{tx.asset}/#{tx.to}"

    with :ok <- nonce_valid?(state, tx.from, tx.nonce),
         :ok <- account_has_at_least?(state, key_src, tx.amount),
         do: {:ok, state |> apply_send(tx.amount, tx.from, key_src, key_dest)}

  end

  def exec(state, %Transaction.SignedTx{raw_tx: %Transaction.SignOff{} = tx}) do

    with :ok <- nonce_valid?(state, tx.sender, tx.nonce),
         :ok <- sign_off_incremental?(state, tx.height, tx.sender),
         do: {:ok, state |> apply_sign_off(tx.height, tx.hash, tx.sender)}
  end
  
  defp account_has_at_least?(state, key_src, amount) do
    if Map.get(state, key_src, 0) >= amount, do: :ok, else: {:error, :insufficient_funds}
  end

  defp nonce_valid?(state, src, nonce) do
    if Map.get(state, "nonces/#{src}", 0) == nonce, do: :ok, else: {:error, :invalid_nonce}
  end

  defp not_too_much?(amount_entering) do
    # FIXME: this probably should be changed to be taken care off earlier on - on transaction parsing
    # probably in state-less transaction validation
    
    # limits the ability to exploit BEAM's uncapped integer in an attack.
    # Has nothing to do with token supply mechanisms
    if amount_entering < @max_amount, do: :ok, else: {:error, :amount_way_too_large}
  end

  defp is_issuer?(state, token_addr, address) do
    case Map.get(state, "tokens/#{token_addr}/issuer") do
      nil -> {:error, :unknown_issuer}
      ^address -> :ok
      _ -> {:error, :incorrect_issuer}
    end
  end

  defp sign_off_incremental?(state, height, sender) do
    case Map.get(state, "sign_offs/#{sender}") do
      nil -> :ok  # first sign off ever always correct
      %{height: old_height} when is_integer(old_height) and old_height < height -> :ok
      %{height: old_height} when is_integer(old_height) -> {:error, :sign_off_not_incremental}
    end
  end

  defp apply_create_token(state, issuer, nonce) do
    token_addr = HonteD.Token.create_address(issuer, nonce)
    state
    |> bump_nonce(issuer)
    |> Map.put("tokens/#{token_addr}/issuer", issuer)
    |> Map.put("tokens/#{token_addr}/total_supply", 0)
    # FIXME: check for duplicate entries or don't care?
    |> Map.update("issuers/#{issuer}", [token_addr], fn previous -> [token_addr | previous] end)
  end

  defp apply_issue(state, asset, amount, dest, issuer) do
    key_dest = "accounts/#{asset}/#{dest}"
    state
    |> bump_nonce(issuer)
    |> Map.update(key_dest, amount, &(&1 + amount))
    |> Map.update("tokens/#{asset}/total_supply", amount, &(&1 + amount))
  end

  defp apply_send(state, amount, src, key_src, key_dest) do
    state
    |> bump_nonce(src)
    |> Map.update!(key_src, &(&1 - amount))
    |> Map.update(key_dest, amount, &(&1 + amount))
  end

  defp apply_sign_off(state, height, hash, sender) do
    state
    |> bump_nonce(sender)
    |> Map.put("sign_offs/#{sender}", %{height: height, hash: hash})
  end
  
  defp bump_nonce(state, address) do
    state
    |> Map.update("nonces/#{address}", 1, &(&1 + 1))
  end

  def hash(state) do
    # FIXME: crudest of all app state hashes
    state
    |> OJSON.encode!  # using OJSON instead of inspect to have crypto-ready determinism
    |> HonteD.Crypto.hash
  end

  defp scan_potential_issued(unfiltered_tokens, state, issuer) do
    unfiltered_tokens
    |> Enum.filter(fn token_addr -> state["tokens/#{token_addr}/issuer"] == issuer end)
  end

end

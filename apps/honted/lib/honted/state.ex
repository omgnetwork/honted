defmodule HonteD.State do
  @moduledoc """
  Main workhorse of the `honted` ABCI app. Manages the state of the application replicated on the blockchain
  """
  alias HonteDLib.Transaction

  @max_amount round(:math.pow(2,256))  # used to limit integers handled on-chain

  def empty(), do: %{}

  def exec(state, %Transaction.SignedTx{raw_tx: %Transaction.CreateToken{} = tx, signature: signature}) do
    signed_part =
      tx
      |> HonteDLib.TxCodec.encode

    with {:ok} <- nonce_valid?(state, tx.issuer, tx.nonce),
         {:ok} <- signed?(signed_part, signature, tx.issuer),
         do: {:ok, state |> apply_create_token(tx.issuer, tx.nonce)}
  end

  def exec(state, %Transaction.SignedTx{raw_tx: %Transaction.Issue{} = tx, signature: signature}) do
    signed_part =
      tx
      |> HonteDLib.TxCodec.encode

    with {:ok} <- positive?(tx.amount),
         {:ok} <- nonce_valid?(state, tx.issuer, tx.nonce),
         {:ok} <- is_issuer?(state, tx.asset, tx.issuer),
         {:ok} <- not_too_much?(state["tokens/#{tx.asset}/total_supply"] + tx.amount),
         {:ok} <- signed?(signed_part, signature, tx.issuer),
         do: {:ok, state |> apply_issue(tx.asset, tx.amount, tx.dest, tx.issuer)}
  end

  def exec(state, %Transaction.SignedTx{raw_tx: %Transaction.Send{} = tx, signature: signature}) do
    key_src = "accounts/#{tx.asset}/#{tx.from}"
    key_dest = "accounts/#{tx.asset}/#{tx.to}"
    signed_part =
      tx
      |> HonteDLib.TxCodec.encode

    with {:ok} <- positive?(tx.amount),
         {:ok} <- nonce_valid?(state, tx.from, tx.nonce),
         {:ok} <- account_has_at_least?(state, key_src, tx.amount),
         {:ok} <- signed?(signed_part, signature, tx.from),
         do: {:ok, state |> apply_send(tx.amount, tx.from, key_src, key_dest)}

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
    # FIXME: this probably should be changed to be taken care off earlier on - on transaction parsing
    # probably in state-less transaction validation
    
    # limits the ability to exploit BEAM's uncapped integer in an attack.
    # Has nothing to do with token supply mechanisms
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
    token_addr = HonteDLib.Token.create_address(issuer, nonce)
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

  defp bump_nonce(state, address) do
    state
    |> Map.update("nonces/#{address}", 1, &(&1 + 1))
  end

  defp signed?(signed_part, signature, src) do
    case HonteDLib.Crypto.verify(signed_part, signature, src) do
      {:ok, true} -> {:ok}
      {:ok, false} -> {:invalid_signature}
      _ -> {:malformed_signature}
    end
  end

  def hash(state) do
    # FIXME: crudest of all app state hashes
    state
    |> OJSON.encode!  # using OJSON instead of inspect to have crypto-ready determinism
    |> HonteDLib.Crypto.hash
  end
end

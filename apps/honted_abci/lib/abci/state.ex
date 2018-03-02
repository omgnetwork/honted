defmodule HonteD.ABCI.State do
  @moduledoc """
  Main workhorse of the `honted` ABCI app. Manages the state of the application replicated on the blockchain
  """
  alias HonteD.ABCI.State.ProcessRegistryDB
  alias MerklePatriciaTree.Trie
  alias HonteD.ABCI.MPTState
  alias HonteD.Transaction
  alias HonteD.Staking

  @max_amount round(:math.pow(2, 256))  # used to limit integers handled on-chain
  @epoch_number_key "contract/epoch_number"
  # indicates that epoch change is in progress, is set to true in epoch change transaction
  # and set to false when state is processed in EndBlock
  @epoch_change_key "contract/epoch_change"

  def initial(db_name) do
    trie = MerklePatriciaTree.Trie.new(ProcessRegistryDB.init(db_name))
    trie
    |> MPTState.put(@epoch_number_key, 0)
    |> MPTState.put(@epoch_change_key, false)
  end

  def lookup(state, key) do
    case MPTState.get(state, key) do
      nil -> nil
      value -> {:ok, value}
    end
  end

  def lookup(state, key, default) do
    case lookup(state, key) do
      nil -> {:ok, default}
      v -> v
    end
  end

  def issued_tokens(state, address) do
    key = "issuers/" <> to_string(address)
    case MPTState.get(state, key) do
      nil -> nil
      value -> {:ok, value |> scan_potential_issued(state, to_string(address))}
    end
  end

  def exec(state, %Transaction.SignedTx{raw_tx: %Transaction.CreateToken{} = tx}) do

    with :ok <- nonce_valid?(state, tx.issuer, tx.nonce),
         do: {:ok, state
                   |> apply_create_token(tx.issuer, tx.nonce)
                   |> bump_nonce_after(tx)}
  end

  def exec(state, %Transaction.SignedTx{raw_tx: %Transaction.Issue{} = tx}) do

    with :ok <- nonce_valid?(state, tx.issuer, tx.nonce),
         :ok <- is_issuer?(state, tx.asset, tx.issuer),
         :ok <- not_too_much?(tx.amount, MPTState.get(state, "tokens/#{tx.asset}/total_supply")),
         do: {:ok, state
                   |> apply_change_asset(tx.asset, tx.amount, tx.dest)
                   |> bump_nonce_after(tx)}
  end

  def exec(state, %Transaction.SignedTx{raw_tx: %Transaction.Unissue{} = tx}) do
    key_src = "accounts/#{tx.asset}/#{tx.issuer}"

    with :ok <- nonce_valid?(state, tx.issuer, tx.nonce),
         :ok <- is_issuer?(state, tx.asset, tx.issuer),
         :ok <- account_has_at_least?(state, key_src, tx.amount),
         do:
           {:ok,
            state
            |> apply_change_asset(tx.asset, -tx.amount, tx.issuer)
            |> bump_nonce_after(tx)}
  end

  def exec(state, %Transaction.SignedTx{raw_tx: %Transaction.Send{} = tx}) do
    key_src = "accounts/#{tx.asset}/#{tx.from}"
    key_dest = "accounts/#{tx.asset}/#{tx.to}"

    with :ok <- nonce_valid?(state, tx.from, tx.nonce),
         :ok <- account_has_at_least?(state, key_src, tx.amount),
         do: {:ok, state
                  |> apply_send(tx.amount, key_src, key_dest)
                  |> bump_nonce_after(tx)}
  end

  def exec(state, %Transaction.SignedTx{raw_tx: %Transaction.SignOff{} = tx}) do
    with :ok <- nonce_valid?(state, tx.sender, tx.nonce),
         :ok <- allows_for?(state, tx.signoffer, tx.sender, :signoff),
         :ok <- sign_off_incremental?(state, tx.height, tx.signoffer),
         do: {:ok, state
                   |> apply_sign_off(tx.height, tx.hash, tx.signoffer)
                   |> bump_nonce_after(tx)}
  end

  def exec(state, %Transaction.SignedTx{raw_tx: %Transaction.Allow{} = tx}) do
    with :ok <- nonce_valid?(state, tx.allower, tx.nonce),
         do: {:ok, state
                   |> apply_allow(tx.allower, tx.allowee, tx.privilege, tx.allow)
                   |> bump_nonce_after(tx)}
  end

  def exec(state, %Transaction.SignedTx{raw_tx: %Transaction.EpochChange{} = tx},
   %Staking{} = staking_state) do
    with :ok <- nonce_valid?(state, tx.sender, tx.nonce),
         :ok <- validator_block_passed?(staking_state, epoch_number(state)),
         :ok <- epoch_valid?(state, tx.epoch_number),
         do: {:ok, state
                   |> apply_epoch_change
                   |> bump_nonce_after(tx)}
  end

  def validator_block_passed?(staking, epoch) do
    # We enumerate epochs starting from 0
    # Calculating validator block height is based on HonteStaking Ethereum contract
    # Keep the logic consistent with contract code
    validator_block =
      staking.start_block + staking.epoch_length * (epoch + 1) - staking.maturity_margin
    if validator_block <= staking.ethereum_block_height do
      :ok
    else
      {:error, :validator_block_has_not_passed}
    end
  end

  defp epoch_valid?(state, epoch_number) do
    is_next_epoch = epoch_number(state) == epoch_number - 1
    if is_next_epoch and not epoch_change?(state), do: :ok, else: {:error, :invalid_epoch_change}
  end

  defp account_has_at_least?(state, key_src, amount) do
    {:ok, stored_amount} = lookup(state, key_src, 0)
    if stored_amount >= amount, do: :ok, else: {:error, :insufficient_funds}
  end

  defp nonce_valid?(state, src, nonce) do
    {:ok, stored_nonce} = lookup(state, "nonces/#{src}", 0)
    if stored_nonce == nonce, do: :ok, else: {:error, :invalid_nonce}
  end

  defp not_too_much?(amount_entering, amount_present)
  when amount_entering >= 0 and
       amount_present >= 0 do
    # limits the ability to exploit BEAM's uncapped integer in an attack.
    # Has nothing to do with token supply mechanisms
    # NOTE: this is a stateful test,
    # the state-less test is better handled by limitting the tx's byte-size
    if amount_entering + amount_present < @max_amount, do: :ok, else: {:error, :amount_way_too_large}
  end

  defp is_issuer?(state, token_addr, address) do
    case MPTState.get(state, "tokens/#{token_addr}/issuer") do
      nil -> {:error, :unknown_issuer}
      ^address -> :ok
      _ -> {:error, :incorrect_issuer}
    end
  end

  defp sign_off_incremental?(state, height, sender) do
    case MPTState.get(state, "sign_offs/#{sender}") do
      nil -> :ok  # first sign off ever always correct
      %{height: old_height} when is_integer(old_height) and old_height < height -> :ok
      %{height: old_height} when is_integer(old_height) -> {:error, :sign_off_not_incremental}
    end
  end

  defp allows_for?(state, allower, allowee, privilege) when is_atom(privilege) do
    # checks whether allower allows allowee for privilege

    # always self-allow and in case allower != allowee - check delegations in state
    if allower == allowee or MPTState.get(state, "delegations/#{allower}/#{allowee}/#{privilege}") do
      :ok
    else
      {:error, :invalid_delegation}
    end
  end

  defp apply_create_token(state, issuer, nonce) do
    token_addr = HonteD.Token.create_address(issuer, nonce)
    state
    |> MPTState.put("tokens/#{token_addr}/issuer", issuer)
    |> MPTState.put("tokens/#{token_addr}/total_supply", 0)
    # NOTE: check for duplicate entries or don't care?
    |> MPTState.update("issuers/#{issuer}", [token_addr], fn previous -> [token_addr | previous] end)
  end

  defp apply_change_asset(state, asset, amount, dest) do
    key_dest = "accounts/#{asset}/#{dest}"
    state
    |> MPTState.update(key_dest, amount, &(&1 + amount))
    |> MPTState.update("tokens/#{asset}/total_supply", amount, &(&1 + amount))
  end

  defp apply_send(state, amount, key_src, key_dest) do
    state
    |> MPTState.update!(key_src, &(&1 - amount))
    |> MPTState.update(key_dest, amount, &(&1 + amount))
  end

  defp apply_sign_off(state, height, hash, signoffer) do
    state
    |> MPTState.put("sign_offs/#{signoffer}", %{height: height, hash: hash})
  end

  defp apply_allow(state, allower, allowee, privilege, allow) do
    state
    |> MPTState.put("delegations/#{allower}/#{allowee}/#{privilege}", allow)
  end

  defp apply_epoch_change(state) do
    state
    |> MPTState.put(@epoch_change_key, true)
    |> MPTState.update!(@epoch_number_key, &(&1 + 1))
  end

  defp bump_nonce_after(state, tx) do
    sender = Transaction.Validation.sender(tx)
    key = "nonces/#{sender}"
    {:ok, current_nonce} = lookup(state, key, 0)
    MPTState.put(state, key, current_nonce + 1)
  end

  def hash(state), do: state.root_hash

  defp scan_potential_issued(unfiltered_tokens, state, issuer) do
    unfiltered_tokens
    |> Enum.filter(fn token_addr -> MPTState.get(state, "tokens/#{token_addr}/issuer") == issuer end)
  end

  def epoch_change?(state) do
    {:ok, value} = lookup(state, @epoch_change_key, false)
    value
  end

  def not_change_epoch(state), do: MPTState.put(state, @epoch_change_key, false)

  def epoch_number(state), do: MPTState.get(state, @epoch_number_key)

  @doc """
  Returns copy of the first argument.
  Copied database is stored in process dictionary under copy_name key.
  """
  def copy_state(%Trie{db: {ProcessRegistryDB, db_name}, root_hash: root_hash},
                 %Trie{db: {ProcessRegistryDB, copy_name}} = copy) do
    :ok = ProcessRegistryDB.copy_db(db_name, copy_name)
    %{copy | root_hash: root_hash}
  end

end

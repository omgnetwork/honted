#   Copyright 2018 OmiseGO Pte Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

defmodule HonteD.API do
  @moduledoc """
  Implements the API to be exposed via various means: JSONRPC2.0, cli, other?

  Should abstract out all Tendermint-related stuff
  """

  use HonteD.API.ExposeSpec

  alias HonteD.API.{Tendermint, Tools}
  alias HonteD.{Transaction, TxCodec}

  @type tx_status :: :failed | :committed | :finalized | :committed_unknown

  @doc """
  Creates a signable, encoded transaction that creates a new token for an issuer
  """
  @spec create_create_token_transaction(issuer :: binary)
        :: {:ok, binary} | {:error, map}
  def create_create_token_transaction(issuer) do
    client = Tendermint.RPC.client()
    with {:ok, nonce} <- Tools.get_nonce(client, issuer),
         {:ok, tx} <- Transaction.create_create_token(nonce: nonce, issuer: issuer) do
      {:ok, tx |> TxCodec.encode() |> Base.encode16()}
    end
  end

  @doc """
  Creates a signable, encoded transaction that issues `amount` `asset`-tokens to `to`

  NOTE: total_supply issuable is capped at 2^256, to limit the capability to exploit unlimited integers in BEAM
        see code that handles state transition for issuing.
        This cap has nothing to do with token supply
  """
  @spec create_issue_transaction(asset :: binary, amount :: pos_integer, to :: binary, issuer :: binary)
        :: {:ok, binary} | {:error, map}
  def create_issue_transaction(asset, amount, to, issuer) do
    client = Tendermint.RPC.client()
    with {:ok, nonce} <- Tools.get_nonce(client, issuer),
         {:ok, tx} <- Transaction.create_issue(nonce: nonce, asset: asset, amount: amount, dest: to,
           issuer: issuer) do
      {:ok, tx |> TxCodec.encode() |> Base.encode16()}
    end
  end

  @doc """
  Creates a signable, encoded transaction that unissues `amount` of `asset`-tokens, reducing total supply
  """
  @spec create_unissue_transaction(asset :: binary, amount :: pos_integer, issuer :: binary)
        :: {:ok, binary} | {:error, map}
  def create_unissue_transaction(asset, amount, issuer) do
    client = Tendermint.RPC.client()
    with {:ok, nonce} <- Tools.get_nonce(client, issuer),
         {:ok, tx} <- Transaction.create_unissue(nonce: nonce, asset: asset, amount: amount, issuer: issuer) do
      {:ok, tx |> TxCodec.encode() |> Base.encode16()}
    end
  end

  @doc """
  Creates a signable, encoded transaction that sends `amount` of `asset` from `from` to `to`
  """
  @spec create_send_transaction(asset :: binary, amount :: pos_integer, from :: binary, to :: binary)
        :: {:ok, binary} | {:error, map}
  def create_send_transaction(asset, amount, from, to) do
    client = Tendermint.RPC.client()
    with {:ok, nonce} <- Tools.get_nonce(client, from),
         {:ok, tx} <- Transaction.create_send(nonce: nonce, asset: asset, amount: amount,
           from: from, to: to) do
      {:ok, tx |> TxCodec.encode() |> Base.encode16()}
    end
  end

  @doc """
  Creates a signable, encoded transaction that signs off the blockchain till `height` for `sender`
  denoting the correct signed-off chain branch by specifying a block `hash`
  """
  @spec create_sign_off_transaction(height :: pos_integer, hash :: binary, sender :: binary, signoffer :: binary)
        :: {:ok, binary} | {:error, map}
  def create_sign_off_transaction(height, hash, sender, signoffer) do
    client = Tendermint.RPC.client()
    with {:ok, nonce} <- Tools.get_nonce(client, sender),
         {:ok, tx} <- Transaction.create_sign_off(nonce: nonce, height: height, hash: hash,
           sender: sender, signoffer: signoffer) do
      {:ok, tx |> TxCodec.encode() |> Base.encode16()}
    end
  end

  @doc """
  Creates a signable, encoded transaction that allows `allowee` to do `privilege` on behalf of `allower`
  (or revokes this, if `allow` is `:false`)
  """
  @spec create_allow_transaction(allower :: binary, allowee :: binary, privilege :: binary, allow :: boolean)
        :: {:ok, binary} | {:error, map}
  def create_allow_transaction(allower, allowee, privilege, allow) do
    client = Tendermint.RPC.client()
    with {:ok, nonce} <- Tools.get_nonce(client, allower),
         {:ok, tx} <- Transaction.create_allow(nonce: nonce, allower: allower, allowee: allowee,
           privilege: privilege, allow: allow) do
          {:ok, tx |> TxCodec.encode() |> Base.encode16()}
    end
  end

  @doc """
  Creates a signable, encoded transaction that notifies about epoch change
  """
  @spec create_epoch_change_transaction(sender :: binary, epoch_number :: pos_integer)
        :: {:ok, binary} | {:error, map}
  def create_epoch_change_transaction(sender, epoch_number) do
    client = Tendermint.RPC.client()
    with {:ok, nonce} <- Tools.get_nonce(client, sender),
         {:ok, tx} <- Transaction.create_epoch_change(nonce: nonce, sender: sender,
         epoch_number: epoch_number) do
      {:ok, tx |> TxCodec.encode() |> Base.encode16()}
    end
  end

  @doc """
  Submits a signed transaction, blocks until its committed by the validators
  """
  @spec submit_commit(transaction :: binary) :: {:ok, %{tx_hash: binary,
                                                        committed_in: non_neg_integer}} | {:error, map}
  def submit_commit(transaction) do
    client = Tendermint.RPC.client()
    transaction = Base.decode16!(transaction)
    rpc_response = Tendermint.RPC.broadcast_tx_commit(client, transaction)
    case rpc_response do
      # successes / no-ops
      {:ok, %{"check_tx" => %{"code" => 0}, "hash" => hash, "height" => height,
              "deliver_tx" => %{"code" => 0}}} ->
        {:ok, %{tx_hash: hash, committed_in: height}}
      # failures
      {:ok, %{"check_tx" => %{"code" => 0}, "hash" => hash} = result} ->
        {:error, %{reason: :deliver_tx_failed, tx_hash: hash, raw_result: result}}
      {:ok, %{"check_tx" => %{"code" => code, "data" => data, "log" => log}, "hash" => hash}} ->
        {:error, %{reason: :check_tx_failed, tx_hash: hash, code: code, data: data, log: log}}
      result ->
        {:error, %{reason: :unknown_error, raw_result: inspect result}}
    end
  end

  @doc """
  Submits a signed transaction, blocks until it's validated by local mempool
  """
  @spec submit_sync(transaction :: binary) :: {:ok, %{tx_hash: binary}} | {:error, map}
  def submit_sync(transaction) do
    client = Tendermint.RPC.client()
    transaction = Base.decode16!(transaction)
    rpc_response = Tendermint.RPC.broadcast_tx_sync(client, transaction)
    case rpc_response do
      # successes / no-ops
      {:ok, %{"code" => 0, "hash" => hash}} ->
        {:ok, %{tx_hash: hash}}
        # failures
        {:ok, %{"code" => code, "data" => data, "log" => log, "hash" => hash}} ->
        {:error, %{reason: :submit_failed, tx_hash: hash, code: code, data: data, log: log}}
      result ->
        {:error, %{reason: :unknown_error, raw_result: inspect result}}
    end
  end

  @doc """
  Submits a signed transaction, blocks for a RPC roundtrip time, checks for mempool duplicates
  """
  @spec submit_async(transaction :: binary) :: {:ok, %{tx_hash: binary}} | {:error, map}
  def submit_async(transaction) do
    client = Tendermint.RPC.client()
    transaction = Base.decode16!(transaction)
    rpc_response = Tendermint.RPC.broadcast_tx_async(client, transaction)
    case rpc_response do
      # successes / no-ops
      {:ok, %{"code" => 0, "hash" => hash}} ->
        {:ok, %{tx_hash: hash}}
      # failures
      result ->
        {:error, %{reason: :unknown_error, raw_result: inspect result}}
    end
  end

  @doc """
  Queries a current balance in `asset` for a particular `address`
  """
  @spec query_balance(token :: binary, address :: binary) :: {:ok, non_neg_integer} | {:error, map}
  def query_balance(token, address)
  when is_binary(token) and
       is_binary(address) do
    client = Tendermint.RPC.client()
    Tools.get_and_decode(client, "/accounts/#{token}/#{address}")
  end

  @doc """
  Lists tokens issued by a particular address
  """
  @spec tokens_issued_by(issuer :: binary) :: {:ok, [binary]} | {:error, map}
  def tokens_issued_by(issuer)
  when is_binary(issuer) do
    client = Tendermint.RPC.client()
    Tools.get_and_decode(client, "/issuers/#{issuer}")
  end

  @doc """
  Get detailed information for a particular token
  """
  @spec token_info(token :: binary) :: {:ok, %{token: binary,
                                               issuer: binary,
                                               total_supply: non_neg_integer}} | {:error, map}
  def token_info(token)
  when is_binary(token) do
    client = Tendermint.RPC.client()
    with {:ok, issuer} <- Tools.get_issuer(client, token),
         {:ok, total_supply} <- Tools.get_and_decode(client, "/tokens/#{token}/total_supply"),
         do: {:ok, %{token: token, issuer: issuer, total_supply: total_supply}}
  end

  @doc """
  Queries for detailed data on a particular submitted transaction with hash `hash`.
  Appends a convenience field `decoded_tx` to the details supplied by Tendermint
  """
  @spec tx(hash :: binary) :: {:ok, %{status: tx_status}} | {:error, %{reason: :unknown_error, raw_result: binary}}
  def tx(hash) when is_binary(hash) do
    client = Tendermint.RPC.client()
    rpc_response = Tendermint.RPC.tx(client, hash)
    case rpc_response do
      # successes (incl.successful look up of failed tx)
      {:ok, tx_info} -> {:ok, tx_info
                              |> Tools.append_status(client) |> Tools.encode_tx()}
      # failures
      result ->
        {:error, %{reason: :unknown_error, raw_result: inspect result}} # NOTE not able to handle "not found"!
    end
  end

  @doc """
  Create a filter that will replay notifications about historical Send transaction for `watched` address.
  Transactions matching predicate included in all blocks from `first` to `last` will be delivered.
  Transactions will be sent to `subscriber` with status :committed. To check if transaction
  was finalized call `tx/1`.

  Returns `{:ok, %{history_filter: t:HonteD.filter_id/0}}`. Value of `history_filter` will
  be used in delivered messages as indicator of source, but it can't be used in
  `drop_filter/1` or `status_filter/1`.

  See `HonteD.API.Eventer.message/4` for reference of messages sent to `subscriber`
  """
  @spec new_send_filter_history(subscriber :: pid, watched :: HonteD.address,
                                first :: HonteD.block_height, last :: HonteD.block_height)
    :: {:ok, %{history_filter: HonteD.filter_id}} | {:error, HonteD.API.Events.badarg}
  def new_send_filter_history(subscriber, watched, first, last) do
    HonteD.API.Events.new_send_filter_history(subscriber, watched, first, last)
  end

  @doc """
  Create a filter that will deliver notification about new Send transaction mined for `watched` address
  Notifications will be delivered as {:committed | :finalized, event} messages to `subscriber`.

  Returns `{:ok, %{new_filter: t:HonteD.filter_id, start_height: t:HonteD.block_height}}`. Value
  of `new_filter` can be used in `status_filter/1` and `drop_filter/1` calls and will be added
  to messages generated by filter as an indication of their source. `start_height` denotes
  first block for which notifications will be delivered.

  See `HonteD.API.Eventer.message/4` for reference of messages sent to `subscriber`
  """
  @spec new_send_filter(subscriber :: pid, watched :: HonteD.address)
    :: {:ok, %{new_filter: HonteD.filter_id, start_height: HonteD.block_height}}
     | {:error, HonteD.API.Events.badarg}
  def new_send_filter(subscriber, watched) do
    HonteD.API.Events.new_send_filter(subscriber, watched)
  end

  @doc """
  Remove particular filter. Can be used only with filters created by `new_send_filter/4`
  """
  @spec drop_filter(filter_id :: HonteD.filter_id)
    :: :ok | {:error, :notfound | HonteD.API.Events.badarg}
  def drop_filter(filter_id) do
    HonteD.API.Events.drop_filter(filter_id)
  end

  @doc """
  Get information about particular filter. Can be used only with filters created by `new_send_filter/4`

  Returns `{:ok, [binary]}` with a list of topics (currently single topic denoting token receiver).
  """
  @spec status_filter(filter_id :: HonteD.filter_id)
    :: {:ok, [binary]} | {:error, :notfound | HonteD.API.Events.badarg}
  def status_filter(filter_id) do
    HonteD.API.Events.status_filter(filter_id)
  end

end

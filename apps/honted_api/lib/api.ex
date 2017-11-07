defmodule HonteD.API do
  @moduledoc """
  Implements the API to be exposed via various means: JSONRPC2.0, cli, other?

  Should abstract out all Tendermint-related stuff
  """

  use HonteD.API.ExposeSpec

  alias HonteD.API.{TendermintRPC, Tools}
  alias HonteD.{Transaction}

  @doc """
  Creates a signable, encoded transaction that creates a new token for an issuer
  """
  @spec create_create_token_transaction(issuer :: binary)
        :: {:ok, binary} | any
  def create_create_token_transaction(issuer) do
    client = TendermintRPC.client()
    with {:ok, nonce} <- Tools.get_nonce(client, issuer),
         do: Transaction.create_create_token(nonce: nonce, issuer: issuer)
  end

  @doc """
  Creates a signable, encoded transaction that issues `amount` `asset`-tokens to `to`
  
  NOTE: total_supply issuable is capped at 2^256, to limit the capability to exploit unlimited integers in BEAM
        see code that handles state transition for issuing.
        This cap has nothing to do with token supply
  """
  @spec create_issue_transaction(asset :: binary, amount :: pos_integer, to :: binary, issuer :: binary)
        :: {:ok, binary} | any
  def create_issue_transaction(asset, amount, to, issuer) do
    client = TendermintRPC.client()
    with {:ok, nonce} <- Tools.get_nonce(client, issuer),
         do: Transaction.create_issue(nonce: nonce,
                                      asset: asset,
                                      amount: amount,
                                      dest: to,
                                      issuer: issuer)
  end

  @doc """
  Creates a signable, encoded transaction that sends `amount` of `asset` from `from` to `to`
  """
  @spec create_send_transaction(asset :: binary, amount :: pos_integer, from :: binary, to :: binary)
        :: {:ok, binary} | any
  def create_send_transaction(asset, amount, from, to) do
    client = TendermintRPC.client()
    with {:ok, nonce} <- Tools.get_nonce(client, from),
         do: Transaction.create_send(nonce: nonce,
                                     asset: asset,
                                     amount: amount,
                                     from: from,
                                     to: to)
  end

  @doc """
  Creates a signable, encoded transaction that signs off the blockchain till `height` for `sender`
  denoting the correct signed-off chain branch by specifying a block `hash`
  """
  @spec create_sign_off_transaction(height :: pos_integer, hash :: binary, sender :: binary)
        :: {:ok, binary} | any
  def create_sign_off_transaction(height, hash, sender) do
    client = TendermintRPC.client()
    with {:ok, nonce} <- Tools.get_nonce(client, sender),
         do: Transaction.create_sign_off(nonce: nonce,
                                         height: height,
                                         hash: hash,
                                         sender: sender)
  end

  @doc """
  Submits a signed transaction, blocks until its committed by the validators
  """
  @spec submit_transaction(transaction :: binary) :: {:ok, map} | {:error, map}
  def submit_transaction(transaction) do
    client = TendermintRPC.client()
    rpc_response = TendermintRPC.broadcast_tx_commit(client, transaction)
    case rpc_response do
      # successes / no-ops
      {:ok, %{"check_tx" => %{"code" => 0}, "hash" => hash, "height" => height,
              "deliver_tx" => %{"code" => 0}}} ->
        {:ok, %{tx_hash: hash, duplicate: false, committed_in: height}}
      {:ok, %{"check_tx" => %{"code" => 3}, "hash" => hash}} ->
        {:ok, %{tx_hash: hash, duplicate: true, committed_in: nil}}
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
  Queries a current balance in `asset` for a particular `address`
  
  {:ok, balance} on success
  garbage on error (FIXME!!)
  """
  @spec query_balance(token :: binary, address :: binary) :: {:ok, non_neg_integer} | any
  def query_balance(token, address)
  when is_binary(token) and
       is_binary(address) do
    client = TendermintRPC.client()
    rpc_response = TendermintRPC.abci_query(client, "", "/accounts/#{token}/#{address}")
    with {:ok, %{"response" => %{"code" => 0, "value" => balance_encoded}}} <- rpc_response,
         do: TendermintRPC.to_int(balance_encoded)
  end
  
  @doc """
  Lists tokens issued by a particular address
  
  {:ok, list_of_tokens} on success
  garbage on error (FIXME!!)
  """
  @spec tokens_issued_by(issuer :: binary) :: {:ok, [binary]} | any
  def tokens_issued_by(issuer)
  when is_binary(issuer) do
    client = TendermintRPC.client()
    rpc_response = TendermintRPC.abci_query(client, "", "/issuers/#{issuer}")
    with {:ok, %{"response" => %{"code" => 0, "value" => token_list_encoded}}} <- rpc_response,
         do: TendermintRPC.to_list(token_list_encoded, 40)
  end
  
  @doc """
  Get detailed information for a particular token
  
  {:ok, info} on success
  garbage on error (FIXME!!)
  """
  @spec token_info(token :: binary) :: {:ok, map} | any
  def token_info(token)
  when is_binary(token) do
    client = TendermintRPC.client()
    with {:ok, issuer} <- Tools.get_issuer(client, token),
         {:ok, total_supply} <- Tools.get_total_supply(client, token),
         do: {:ok, %{token: token, issuer: issuer, total_supply: total_supply}}
  end
  
  @doc """
  Queries for detailed data on a particular submitted transaction with hash `hash`.
  Appends a convenience field `decoded_tx` to the details supplied by Tendermint
  """
  @spec tx(hash :: binary) :: {:ok, map} | {:error, map}
  def tx(hash) when is_binary(hash) do
    client = TendermintRPC.client()
    rpc_response = TendermintRPC.tx(client, hash)
    case rpc_response do
      # successes
      {:ok, %{"height" => _, "tx" => encoded_tx, "tx_result" => %{"code" => 0, "data" => "", "log" => ""}} = tx_info} ->
        {:ok, tx_info |> Map.put(:status, :committed)
                      |> Tools.append_decoded(encoded_tx)}
      {:ok, %{"tx" => encoded_tx, "tx_result" => %{"code" => 0, "data" => "", "log" => ""}} = tx_info} ->
        {:ok, tx_info |> Map.put(:status, :pending)
                      |> Tools.append_decoded(encoded_tx)} # NOTE not sure if possible!
      # successful look up of failed tx
      {:ok, %{"tx" => encoded_tx, "tx_result" => _} = tx_info} ->
        {:ok, tx_info |> Map.put(:status, :failed)
                      |> Tools.append_decoded(encoded_tx)} # NOTE not sure if possible!
      # failures
      result -> 
        {:error, %{reason: :unknown_error, raw_result: inspect result}} # NOTE not able to handle "not found"!
    end
  end

  @doc """
  Subscribe to notification about Send transaction mined for particular address.
  Notifications will be delivered as {:committed, event} messages to `subscriber`.

  {:ok, :ok} on success
  {:error, reason} on failure
  """
  @spec new_send_filter(subscriber :: pid, watched :: binary) :: {:ok, :ok} | {:error, atom}
  def new_send_filter(subscriber, watched) do
    HonteD.Events.subscribe_send(subscriber, watched)
  end

  @doc """
  Stop subscribing to notifications about Send transactions mined for particular address.

  {:ok, :ok} on success
  {:error, reason} on failure
  """
  @spec drop_send_filter(subscriber :: pid, watched :: binary) :: {:ok, :ok} | {:error, atom}
  def drop_send_filter(subscriber, watched) do
    HonteD.Events.unsubscribe_send(subscriber, watched)
  end

  @doc """
  Check if one is subscribed to notifications about Send transactions mined for particular
  address.

  {:ok, boolean} on success
  {:error, reason} on failure
  """
  @spec status_send_filter?(subscriber :: pid, watched :: binary) :: {:ok, boolean} | {:error, atom}
  def status_send_filter?(subscriber, watched) do
    HonteD.Events.subscribed?(subscriber, watched)
  end

end

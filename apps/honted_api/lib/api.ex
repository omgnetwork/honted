defmodule HonteD.API do
  @moduledoc """
  Implements the API to be exposed via various means: JSONRPC2.0, cli, other?

  Should abstract out all Tendermint-related stuff
  """

  use HonteD.API.ExposeSpec

  alias HonteD.API.{TendermintRPC, Tools}
  alias HonteD.{Transaction}

  @type tx_status :: :failed | :pending | :committed | :finalized | :committed_unknown

  @doc """
  Creates a signable, encoded transaction that creates a new token for an issuer
  """
  @spec create_create_token_transaction(issuer :: binary)
        :: {:ok, binary} | {:error, map}
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
        :: {:ok, binary} | {:error, map}
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
        :: {:ok, binary} | {:error, map}
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
  @spec create_sign_off_transaction(height :: pos_integer, hash :: binary, sender :: binary, signoffer :: binary)
        :: {:ok, binary} | {:error, map}
  def create_sign_off_transaction(height, hash, sender, signoffer) do
    client = TendermintRPC.client()
    with {:ok, nonce} <- Tools.get_nonce(client, sender),
         do: Transaction.create_sign_off(nonce: nonce,
                                         height: height,
                                         hash: hash,
                                         sender: sender,
                                         signoffer: signoffer)
  end

  @doc """
  Creates a signable, encoded transaction that allows `allowee` to do `privilege` on behalf of `allower`
  (or revokes this, if `allow` is `:false`)
  """
  @spec create_allow_transaction(allower :: binary, allowee :: binary, privilege :: binary, allow :: boolean)
        :: {:ok, binary} | {:error, map}
  def create_allow_transaction(allower, allowee, privilege, allow) do
    client = TendermintRPC.client()
    with {:ok, nonce} <- Tools.get_nonce(client, allower),
         do: Transaction.create_allow(nonce: nonce,
                                      allower: allower,
                                      allowee: allowee,
                                      privilege: privilege,
                                      allow: allow)
  end

  @doc """
  Submits a signed transaction, blocks until its committed by the validators
  """
  @spec submit_transaction(transaction :: binary) :: {:ok, %{tx_hash: binary,
                                                             duplicate: boolean,
                                                             committed_in: non_neg_integer}} | {:error, map}
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
  """
  @spec query_balance(token :: binary, address :: binary) :: {:ok, non_neg_integer} | {:error, map}
  def query_balance(token, address)
  when is_binary(token) and
       is_binary(address) do
    client = TendermintRPC.client()
    Tools.get_and_decode(client, "/accounts/#{token}/#{address}")
  end
  
  @doc """
  Lists tokens issued by a particular address
  """
  @spec tokens_issued_by(issuer :: binary) :: {:ok, [binary]} | {:error, map}
  def tokens_issued_by(issuer)
  when is_binary(issuer) do
    client = TendermintRPC.client()
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
    client = TendermintRPC.client()
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
    client = TendermintRPC.client()
    rpc_response = TendermintRPC.tx(client, hash)
    case rpc_response do
      # successes (incl.successful look up of failed tx)
      {:ok, tx_info} -> {:ok, tx_info
                              |> Tools.append_status(client)}
      # failures
      result -> 
        {:error, %{reason: :unknown_error, raw_result: inspect result}} # NOTE not able to handle "not found"!
    end
  end

  @doc """
  Create a filter that will replay notifications about historical Send transaction for particular address.
  Notifications will be delivered as {:committed | :finalized, event} messages to `subscriber`.
  """
  @spec new_send_filter_history(subscriber :: pid, watched :: HonteD.address,
                                first :: HonteD.block_height, last :: HonteD.block_height)
    :: {:ok, %{history_filter: HonteD.filter_id}} | {:error, HonteD.API.Events.badarg}
  def new_send_filter_history(subscriber, watched, first, last) do
    HonteD.API.Events.new_send_filter_history(subscriber, watched, first, last)
  end

  @doc """
  Create a filter that will deliver notification about new Send transaction mined for particular address.
  Notifications will be delivered as {:committed | :finalized, event} messages to `subscriber`.
  """
  @spec new_send_filter(subscriber :: pid, watched :: HonteD.address)
    :: {:ok, %{new_filter: reference, start_height: HonteD.block_height}} | {:error, HonteD.API.Events.badarg}
  def new_send_filter(subscriber, watched) do
    HonteD.API.Events.new_send_filter(subscriber, watched)
  end

  @doc """
  Remove particular filter.
  """
  @spec drop_filter(filter_id :: reference)
    :: :ok | {:error, :notfound | HonteD.API.Events.badarg}
  def drop_filter(filter_id) do
    HonteD.API.Events.drop_filter(filter_id)
  end

  @doc """
  Get information about particular filter.
  """
  @spec status_filter(filter_id :: reference)
    :: {:ok, [binary]} | {:error, :notfound | HonteD.API.Events.badarg}
  def status_filter(filter_id) do
    HonteD.API.Events.status_filter(filter_id)
  end

end

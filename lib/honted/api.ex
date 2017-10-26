defmodule HonteD.API do
  @moduledoc """
  Implements the API to be exposed via various means: JSONRPC2.0, cli, other?

  Should abstract out all Tendermint-related stuff
  """

  use ExposeSpec

  alias HonteD.TendermintRPC
  import HonteD.API.Tools

  @doc """
  Creates a signable, encoded transaction that creates a new token for an issuer
  """
  @spec create_create_token_transaction(issuer :: binary)
        :: {:ok, binary} | any
  def create_create_token_transaction(issuer) when is_binary(issuer) do
    client = TendermintRPC.client()
    with {:ok, nonce} <- get_nonce(client, issuer),
         do: {:ok, HonteD.TxCodec.encode([nonce, :create_token, issuer])}
  end

  @doc """
  Creates a signable, encoded transaction that issues `amount` `asset`-tokens to `to`
  
  NOTE: total_supply issuable is capped at 2^256, to limit the capability to exploit unlimited integers in BEAM
        see code that handles state transition for issuing.
        This cap has nothing to do with token supply
  """
  @spec create_issue_transaction(asset :: binary, amount :: pos_integer, to :: binary, issuer :: binary)
        :: {:ok, binary} | any
  def create_issue_transaction(asset, amount, to, issuer)
  when is_binary(asset) and
       is_integer(amount) and
       amount > 0 and
       is_binary(issuer) and
       is_binary(to) do
    client = TendermintRPC.client()
    with {:ok, nonce} <- get_nonce(client, issuer),
         do: {:ok, HonteD.TxCodec.encode([nonce, :issue, asset, amount, to, issuer])}
  end

  @doc """
  Creates a signable, encoded transaction that sends `amount` of `asset` from `from` to `to`
  """
  @spec create_send_transaction(asset :: binary, amount :: pos_integer, from :: binary, to :: binary)
        :: {:ok, binary} | any
  def create_send_transaction(asset, amount, from, to)
  when is_binary(asset) and
       is_integer(amount) and
       amount > 0 and
       is_binary(from) and
       is_binary(to) do
    client = TendermintRPC.client()
    with {:ok, nonce} <- get_nonce(client, from),
         do: {:ok, HonteD.TxCodec.encode([nonce, :send, asset, amount, from, to])}
  end

  @doc """
  Submits a signed transaction
  
  {:ok, hash} on success or duplicate transaction
  garbage on error (FIXME!!)
  """
  @spec submit_transaction(transaction :: binary) :: {:ok, binary} | any
  def submit_transaction(transaction) do
    client = TendermintRPC.client()
    rpc_response = TendermintRPC.broadcast_tx_sync(client, transaction)
    with {:ok, %{"code" => code, "hash" => hash}} when code in [0, 3] <- rpc_response,
         do: {:ok, hash}  # either submitted or duplicate
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
         {:ok, decoded} <- Base.decode16(balance_encoded),
         {balance, ""} <- Integer.parse(decoded),
         do: {:ok, balance}
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
         {:ok, decoded} <- Base.decode16(token_list_encoded),
         # translate raw output from abci by cutting into 40-char-long ascii sequences
         do: {:ok, decoded |> String.codepoints |> Enum.chunk_every(40) |> Enum.map(&Enum.join/1)}
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
    with {:ok, issuer} <- get_issuer(client, token),
         {:ok, total_supply} <- get_total_supply(client, token),
         do: {:ok, %{token: token, issuer: issuer, total_supply: total_supply}}
  end
  
  @doc """
  Queries for detailed data on a particular submitted transaction with hash `hash`.
  Appends a convenience field `decoded_tx` to the details supplied by Tendermint
  
  {:ok, details} on success
  garbage on error (FIXME!!)
  """
  @spec tx(hash :: binary) :: {:ok, map} | any
  def tx(hash) when is_binary(hash) do
    client = TendermintRPC.client()
    with {:ok, result} <- TendermintRPC.tx(client, hash),
         {:ok, decoded} <- Base.decode64(result["tx"]),
         result <- Map.put(result, "decoded_tx", decoded), # adding a convenience field to preview the tx
         do: {:ok, result}
  end

  @spec new_send_filter(subscriber :: pid, watched :: binary) :: {:ok, :ok} | {:error, atom}
  def new_send_filter(subscriber, watched) do
    HonteD.Eventer.subscribe_send(subscriber, watched)
  end

  @spec drop_send_filter(subscriber :: pid, watched :: binary) :: {:ok, :ok} | {:error, atom}
  def drop_send_filter(subscriber, watched) do
    HonteD.Eventer.unsubscribe_send(subscriber, watched)
  end

  @spec status_send_filter?(subscriber :: pid, watched :: binary) :: {:ok, boolean} | {:error, atom}
  def status_send_filter?(subscriber, watched) do
    HonteD.Eventer.subscribed?(subscriber, watched)
  end

end

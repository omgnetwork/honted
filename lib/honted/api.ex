defmodule HonteD.API do
  @moduledoc """
  Implements the API to be exposed via various means: JSONRPC2.0, cli, other?

  Should abstract out all Tendermint-related stuff
  """

  alias HonteD.TendermintRPC
  import HonteD.API.Tools

  @doc """
  Creates a signable, encoded transaction that creates a new token for an issuer
  """
  @spec create_create_token_transaction(binary) :: {:ok, binary} | any
  def create_create_token_transaction(issuer) when is_binary(issuer) do
    client = TendermintRPC.client()
    case get_nonce(client, issuer) do
      nonce when is_integer(nonce) -> HonteD.TxCodec.encode([nonce, :create_token, issuer])
      result -> result
    end
  end

  @doc """
  Creates a signable, encoded transaction that issues `amount` `asset`-tokens to `to`
  
  NOTE: amount issuable is capped at 2^256, to limit the capability to exploit unlimited integers in BEAM
        see code that handles state transition for issuing.
        This cap has nothing to do with token supply
  """
  @spec create_issue_transaction(binary, pos_integer, binary, binary) :: {:ok, binary} | any
  def create_issue_transaction(asset, amount, to, issuer)
  when is_binary(asset) and
       is_integer(amount) and
       amount > 0 and
       is_binary(issuer) and
       is_binary(to) do
    client = TendermintRPC.client()
    case get_nonce(client, issuer) do
      nonce when is_integer(nonce) -> HonteD.TxCodec.encode([nonce, :issue, asset, amount, to, issuer])
      result -> result
    end
  end

  @doc """
  Creates a signable, encoded transaction that sends `amount` of `asset` from `from` to `to`
  """
  @spec create_send_transaction(binary, pos_integer, binary, binary) :: {:ok, binary} | any
  def create_send_transaction(asset, amount, from, to)
  when is_binary(asset) and
       is_integer(amount) and
       amount > 0 and
       is_binary(from) and
       is_binary(to) do
    client = TendermintRPC.client()
    case get_nonce(client, from) do
      nonce when is_integer(nonce) -> HonteD.TxCodec.encode([nonce, :send, asset, amount, from, to])
      result -> result
    end
  end

  @doc """
  Submits a signed transaction
  
  {:ok, hash} on success or duplicate transaction
  garbage on error (FIXME!!)
  """
  @spec submit_transaction(binary) :: {:ok, binary} | any
  def submit_transaction(transaction) do
    client = TendermintRPC.client()
    case TendermintRPC.broadcast_tx_sync(client, transaction) do
      {:ok, %{"code" => code, "hash" => hash}} when code in [0, 3] ->
        {:ok, hash}  # either submitted or duplicate
      result -> result
    end
  end
  
  @doc """
  Queries a current balance in `asset` for a particular `address`
  
  {:ok, balance} on success
  garbage on error (FIXME!!)
  """
  @spec query_balance(binary, binary) :: {:ok, non_neg_integer} | any
  def query_balance(asset, address)
  when is_binary(asset) and
       is_binary(address) do
    client = TendermintRPC.client()
    case TendermintRPC.abci_query(client, "", "/accounts/#{asset}/#{address}") do
      {:ok, %{"response" => %{"code" => 0, "value" => balance_enc}}} ->
        {balance, ""} = Integer.parse(Base.decode16!(balance_enc))
        {:ok, balance}
      result -> result
    end
  end
  
  @doc """
  Queries for detailed data on a particular submitted transaction with hash `hash`.
  Appends a convenience field `decoded_tx` to the details supplied by Tendermint
  
  {:ok, details} on success
  garbage on error (FIXME!!)
  """
  @spec tx(binary) :: {:ok, map} | any
  def tx(hash) when is_binary(hash) do
    client = TendermintRPC.client()
    case TendermintRPC.tx(client, hash) do
      {:ok, result} -> result |> Map.put("decoded_tx", Base.decode64(result["tx"]))
      result -> result
    end
  end

end

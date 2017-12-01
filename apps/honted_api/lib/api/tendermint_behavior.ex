defmodule HonteD.API.TendermintBehavior do

  @type result :: {:ok, map} | {:error, any}
  @type tx :: binary
  @type data :: any
  @type path :: binary
  @type hash :: binary
  @type client_ref() :: any

  @callback client() :: client_ref
  @callback broadcast_tx_async(client_ref, tx) :: result
  @callback broadcast_tx_sync(client_ref, tx) :: result
  @callback broadcast_tx_commit(client_ref, tx) :: result
  @callback abci_query(client_ref, data, path) :: result
  @callback tx(client_ref, hash) :: result
  @callback block(client_ref, height :: pos_integer) :: result

end

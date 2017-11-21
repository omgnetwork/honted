defmodule HonteD do
  @type address :: String.t
  @type token :: String.t
  @type signature :: String.t
  @type nonce :: non_neg_integer
  @type block_hash :: String.t # NOTE: this is a hash external to our APP i.e. consensus engine based, e.g. TM block has
  @type block_height :: pos_integer
  @type privilege :: String.t
end

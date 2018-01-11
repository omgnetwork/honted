defmodule HonteD.ABCI.Staking do
  @moduledoc """
  Manages the state of HonteD-OmiseGO Ethereum contract
  """
  defstruct [:ethereum_block_height,
             :start_block,
             :epoch_length,
             :maturity_margin,
            ]

end

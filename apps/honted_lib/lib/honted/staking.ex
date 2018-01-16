defmodule HonteD.Staking do
  @moduledoc """
  Manages the state of HonteStaking Ethereum contract
  """
  defstruct [:ethereum_block_height,
             :start_block,
             :epoch_length,
             :maturity_margin,
             :validators
            ]

end

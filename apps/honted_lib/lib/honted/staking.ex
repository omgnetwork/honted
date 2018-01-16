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

  @doc """
  Tells if validator block has passed.
  """
  def validator_block_passed?(%HonteD.Staking{} = staking, epoch) do
    # We enumerate epochs starting from 0
    validator_block =
      staking.start_block + staking.epoch_length * (epoch + 1) - staking.maturity_margin
    if (validator_block <= staking.ethereum_block_height) do
      :ok
    else
      {:error, :validator_block_has_not_passed}
    end
  end

end

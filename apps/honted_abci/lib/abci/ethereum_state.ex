defmodule HonteD.ABCI.EthereumContractState do
  @moduledoc """
  Manages the state of HonteD-OmiseGO Ethereum contract
  """
  defstruct ethereum_block_height: 0, validator_block_height: 0

  def initial do
    %__MODULE__{}
  end

  def validator_block_passed?(%HonteD.ABCI.EthereumContractState{} = state) do
    if state.ethereum_block_height >= state.validator_block_height do
      :ok
    else
      {:error, :validator_block_has_not_passed}
    end
  end

end

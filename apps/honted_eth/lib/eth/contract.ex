defmodule HonteD.Eth.Contract do
  @moduledoc """
  Ask staking contract for validator and epoch information.
  """
  import Ethereumex.HttpClient
  alias HonteD.Eth.WaitFor, as: WaitFor

  def deploy(epoch_length, maturity_margin, max_validators) do
    {:ok, [addr | _]} = eth_accounts()
    token = File.read!("contracts/omg_token_bytecode.hex")
    {:ok, token_address} = deploy_contract(addr, token, [], [])
    {:ok, staking_address} = deploy_contract(addr, staking_bytecode(),
      [epoch_length, maturity_margin, token_address, max_validators],
      [{:uint, 256}, {:uint, 256}, :address, {:uint, 256}])
    {:ok, token_address, staking_address}
  end

  def block_height do
    {:ok, enc_answer} = eth_block_number()
    decode_answer(enc_answer, [{:uint, 256}])
  end

  def read_validators(staking) do
    current = get_current_epoch(staking)
    max_vals = max_number_of_validators(staking)
    for epoch <- 1..current do
      get_while = fn(index, acc) -> wrap_while(acc, get_validator(staking, epoch, index)) end
      Enum.reduce_while(0..max_vals, [], get_while)
    end
  end

  # FIXME: check if returned values are not zero
  defp wrap_while(acc, {:ok, [{_stake, _tm_addr, _eth_addr} = value]}) do
    {:cont, [value | acc]}
  end

  def get_validator(staking, epoch, index) do
    data = "getValidator(uint256, uint256)" |> ABI.encode([epoch, index]) |> Base.encode16
    {:ok, "0x" <> enc_return} = eth_call(%{to: staking, data: "0x#{data}"})
    decode_answer(enc_return, [{:tuple, [{:uint, 256}, :address, :address]}])
  end

  def in_maturity_margin?(staking) do
    {:ok, current_height} = block_height()
    {:ok, next} = get_next_epoch_block_number(staking)
    {:ok, mm} = maturity_margin(staking)
    current_height > (next - mm)
  end

  def get_current_epoch(staking) do
    call_contract_value(staking, "getCurrentEpoch()")
  end

  def get_next_epoch_block_number(staking) do
    call_contract_value(staking, "getNextEpochBlockNumber()")
  end

  def safety_limit_for_validators(staking) do
    call_contract_value(staking, "safetyLimitForValidators()")
  end

  def max_number_of_validators(staking) do
    call_contract_value(staking, "maxNumberOfValidators()")
  end

  def maturity_margin(staking) do
    call_contract_value(staking, "maturityMargin()")
  end

  def epoch_length(staking) do
    call_contract_value(staking, "epochLength()")
  end

  def start_block(staking) do
    call_contract_value(staking, "startBlock()")
  end

  def unbonding_period(staking) do
    call_contract_value(staking, "unbondingPeriod()")
  end

  def call_contract_value(staking, signature) do
    {:ok, [value]} = call_contract(staking, signature, [], [{:uint, 256}])
    {:ok, value}
  end

  def call_contract(staking, signature, args, return_types) do
    data = signature |> ABI.encode(args) |> Base.encode16
    {:ok, "0x" <> enc_return} = eth_call(%{to: staking, data: "0x#{data}"})
    decode_answer(enc_return, return_types)
  end

  def decode_answer(enc_return, return_types) do
    return =
      enc_return
      |> Base.decode16!(case: :lower)
      |> ABI.TypeDecoder.decode_raw(return_types)
    {:ok, return}
  end

  defp deploy_contract(addr, bytecode, types, args) do
    enc_args = encode_constructor_params(types, args)
    four_mil = "0x3D0900"
    {:ok, txhash} = eth_send_transaction(%{from: addr, data: "0x" <> bytecode <> enc_args, gas: four_mil})
    {:ok, receipt} = WaitFor.receipt(txhash, 10_000)
    %{"contractAddress" => contract_address} = receipt
    {:ok, contract_address}
  end

  defp encode_constructor_params(args, types) do
    args = for arg <- args, do: cleanup(arg)
    args
    |> ABI.TypeEncoder.encode_raw(types)
    |> Base.encode16(case: :lower)
  end

  defp cleanup("0x" <> hex), do: hex |> String.upcase |> Base.decode16!
  defp cleanup(other), do: other

  defp staking_bytecode do
    %{"HonteStaking" => %{"bytecode" => bytecode}} =
      "populus/build/contracts.json"
      |> File.read!()
      |> Poison.decode!()
    String.replace(bytecode, "0x", "")
  end
end

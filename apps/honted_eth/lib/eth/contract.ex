defmodule HonteD.Eth.Contract do
  @moduledoc """
  Ask staking contract for validator and epoch information.

  FIXME: split into dev/integration part and production part
  """
  import Ethereumex.HttpClient
  alias HonteD.Eth.WaitFor, as: WaitFor

  def deploy_dev(epoch_length, maturity_margin, max_validators) do
    deploy("", epoch_length, maturity_margin, max_validators)
  end

  def deploy_integration(epoch_length, maturity_margin, max_validators) do
    deploy("../../", epoch_length, maturity_margin, max_validators)
  end

  # FIXME: refactor for default contract deployment params
  def deploy(root, epoch_length, maturity_margin, max_validators) do
    Application.ensure_all_started(:ethereumex)
    token_bc = File.read!(root <> "contracts/omg_token_bytecode.hex")
    staking_bc = staking_bytecode(root <> "populus/build/contracts.json")
    IO.puts("token: #{inspect bit_size(token_bc)}, staking: #{inspect bit_size(staking_bc)}")
    {:ok, [addr | _]} = eth_accounts()
    {:ok, token_address} = deploy_contract(addr, token_bc, [], [])
    {:ok, staking_address} = deploy_contract(addr, staking_bc,
      [epoch_length, maturity_margin, token_address, max_validators],
      [{:uint, 256}, {:uint, 256}, :address, {:uint, 256}])
    Application.put_env(:honted_eth, :token_contract_address, token_address)
    Application.put_env(:honted_eth, :staking_contract_address, staking_address)
    {:ok, token_address, staking_address}
  end

  def approve(token, addr, benefactor, amount) do
    data = ABI.encode("approve(address,uint256)", [cleanup(benefactor), amount]) |> Base.encode16
    {:ok, txhash} = eth_send_transaction(%{from: addr, data: "0x#{data}", to: token})
    {:ok, receipt} = WaitFor.receipt(txhash, 10_000)
  end

  def deposit(staking, addr, amount) do
    data = ABI.encode("deposit(uint256)", [amount]) |> Base.encode16
    {:ok, txhash} = eth_send_transaction(%{from: addr, data: "0x#{data}", to: staking})
    {:ok, receipt} = WaitFor.receipt(txhash, 10_000)
  end

  def join(staking, addr, tm) do
    false = in_maturity_margin?(staking)
    data = ABI.encode("join(address)", [cleanup(addr)]) |> Base.encode16
    four_mil = "0x3D0900"
    {:ok, txhash} = eth_send_transaction(%{from: addr, to: staking, data: "0x#{data}", gas: four_mil})
    {:ok, receipt} = WaitFor.receipt(txhash, 10_000)
  end

  def mint_omg(token, target, amount) do
    data = ABI.encode("mint(address,uint)", [cleanup(target), amount]) |> Base.encode16
    {:ok, txhash} = eth_send_transaction(%{from: target, to: token, data: "0x#{data}"})
    {:ok, _receipt} = WaitFor.receipt(txhash, 10_000)
  end

  def block_height do
    {:ok, enc_answer} = eth_block_number()
    padded = mb_pad_16(enc_answer)
    {:ok, dec} = Base.decode16(padded, case: :lower)
    :binary.decode_unsigned(dec)
  end

  def read_validators(staking) do
    {:ok, current} = get_current_epoch(staking)
    {:ok, max_vals} = max_number_of_validators(staking)
    for epoch <- 1..current do
      get_while = fn(index, acc) -> wrap_while(acc, get_validator(staking, epoch, index)) end
      %{epoch: epoch, validators: Enum.reduce_while(0..max_vals, [], get_while)}
    end
  end

  defp wrap_while(acc, {:ok, [{0, _tm_addr, _eth_addr}]}) do
    {:halt, acc}
  end
  defp wrap_while(acc, {:ok, [{_, _, _} = value]}) do
    {:cont, [value | acc]}
  end

  def get_validator(staking, epoch, index) do
    return_types = [{:tuple, [{:uint, 256}, :address, :address]}]
    call_contract(staking, "getValidator(uint256,uint256)", [epoch, index], return_types)
  end

  def in_maturity_margin?(staking) do
    current_height = block_height()
    {:ok, next} = get_next_epoch_block_number(staking)
    {:ok, mm} = maturity_margin(staking)
    current_height > (next - mm)
  end

  def balance_of(token, address) do
    signature = "balanceOf(address)"
    {:ok, [value]} = call_contract(token, signature, [cleanup(address)], [{:uint, 256}])
    {:ok, value}
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

  def call_contract(contract, signature, args, return_types) do
    data = signature |> ABI.encode(args) |> Base.encode16
    {:ok, "0x" <> enc_return} = eth_call(%{to: contract, data: "0x#{data}"})
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

  defp staking_bytecode(path) do
    %{"HonteStaking" => %{"bytecode" => bytecode}} =
      path
      |> File.read!()
      |> Poison.decode!()
    String.replace(bytecode, "0x", "")
  end

  def ether, do: trunc(:math.pow(10, 18))

  def eth_hex(num) when is_number(num) do
    hex = [trunc(num)]
      |> ABI.TypeEncoder.encode_raw([{:uint, 256}])
      |> Base.encode16(case: :lower)
    "0x" <> hex
  end

  def mb_pad_16("0x" <> hex) do
    len = trunc(bit_size(hex) / 8)
    evenodd = rem(len, 2)
    case evenodd do
      0 -> hex
      1 -> "0" <> hex
    end
  end
end

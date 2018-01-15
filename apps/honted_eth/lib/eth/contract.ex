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

  def add_validator(token, staking, tm) do
    {:ok, [addr | _]} = eth_accounts()
    mint_omg(token, addr, addr, 10 * ether())
    {:ok, txhash} = contract_join(token, staking, addr, tm, ether())
    {:ok, {addr, tm, 1.0}}
  end

  def mint_omg(token, addr, target, amount) do
    data = ABI.encode("mint(address,uint)", [cleanup(target), amount]) |> Base.encode16
    {:ok, txhash} = eth_send_transaction(%{from: addr, to: token, data: "0x#{data}"})
    {:ok, _receipt} = WaitFor.receipt(txhash, 10_000)
  end

  defp contract_join(token, staking, addr, tm, amount) do
    IO.puts("approve")
    data = ABI.encode("approve(address,uint256)", [cleanup(staking), amount]) |> Base.encode16
    {:ok, txhash} = eth_send_transaction(%{from: addr, data: "0x#{data}", to: token})
    {:ok, receipt} = WaitFor.receipt(txhash, 10_000)
    IO.puts("join")
    data = ABI.encode("join(address)", [cleanup(tm)]) |> Base.encode16
    {:ok, txhash} = eth_send_transaction(%{from: addr, to: staking, data: "0x#{data}"})
    {:ok, receipt} = WaitFor.receipt(txhash, 10_000)
    IO.puts("join done")
    %{"contractAddress" => contract_address} = receipt
    {:ok, contract_address}
  end

  # FIXME: parsing of block height is broken ATM (Elixir bitsyntax)
  def block_height do
    {:ok, enc_answer} = eth_block_number()
    IO.puts("enc #{inspect enc_answer}")
    padded = mb_pad_16(enc_answer)
    IO.puts("padded #{inspect padded}")
    {:ok, dec} = Base.decode16(padded, case: :lower)
    IO.puts("decoded #{inspect dec}")
    <<result :: integer>> = dec
    result
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

  def mb_pad_16(arg = ("0x" <> hex)) do
    len = trunc(bit_size(hex) / 8)
    IO.puts("len: #{len}")
    evenodd = rem(len, 2)
    IO.puts("evenodd: #{evenodd}")
    case evenodd do
      0 -> hex
      1 -> "0" <> hex
    end
  end
end

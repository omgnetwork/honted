defmodule HonteD.Integration.Contract do
  @moduledoc """
  Helper for staking contract operations in integration/tests/dev.
  """
  import Ethereumex.HttpClient
  alias HonteD.Eth.WaitFor, as: WaitFor
  import HonteD.Eth.Contract

  def deploy_dev(epoch_length, maturity_margin, max_validators) do
    deploy("", epoch_length, maturity_margin, max_validators)
  end

  def deploy_integration(epoch_length, maturity_margin, max_validators) do
    deploy("../../", epoch_length, maturity_margin, max_validators)
  end

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
    transact("approve(address,uint256)", [cleanup(benefactor), amount], addr, token)
  end

  def deposit(staking, addr, amount) do
    transact("deposit(uint256)", [amount], addr, staking)
  end

  def join(staking, addr, tm) do
    false = in_maturity_margin?(staking)
    transact("join(address)", [cleanup(tm)], addr, staking)
  end

  def mint_omg(token, target, amount) do
    transact("mint(address,uint)", [cleanup(target), amount], target, token)
  end

  def transact(signature, args, from, contract, timeout \\ 10_000) do
    data =
      signature
      |> ABI.encode(args)
      |> Base.encode16
    gas = "0x3D0900"
    {:ok, txhash} = eth_send_transaction(%{from: from, to: contract, data: "0x#{data}", gas: gas})
    {:ok, _receipt} = WaitFor.receipt(txhash, timeout)
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
end

import json

import ethereum
from ethereum import tester, utils
import pytest
from populus.wait import Wait

from omg_contract_codes import OMGTOKEN_CONTRACT_ABI, OMGTOKEN_CONTRACT_BYTECODE

def deploy(web3, ContractClass):
    deploy_tx = ContractClass.deploy()
    Wait(web3).for_receipt(deploy_tx)
    deploy_receipt = web3.eth.getTransactionReceipt(deploy_tx)
    return ContractClass(address=deploy_receipt['contractAddress'])

@pytest.fixture()
def token(chain, accounts):
    owner = accounts[0]
    contract_class = chain.web3.eth.contract(abi=json.loads(OMGTOKEN_CONTRACT_ABI),
                                             bytecode=OMGTOKEN_CONTRACT_BYTECODE)
    token = deploy(chain.web3, contract_class)
    for addr in accounts:
        chain.wait.for_receipt(
            token.transact({'from': owner}).mint(addr, utils.denoms.ether))
    chain.wait.for_receipt(
        token.transact({'from': owner}).finishMinting())
    return token
    
@pytest.fixture()
def staking(token, chain, accounts):
    owner = accounts[0]
    max_validators = 5
    #args = [token.address, max_validators]
    staking, _ = chain.provider.get_or_deploy_contract('HonteStaking',
                                                       deploy_transaction={'from': owner},
                                                       deploy_args=[])
    return staking

def jump_to_block(chain, block_no):
    # current_block = chain.web3.eth.getBlock('latest').number
    current_block = chain.web3.eth.blockNumber
    assert current_block < block_no
    chain.rpc_methods.evm_mine(block_no - current_block)
    assert chain.web3.eth.blockNumber == block_no

def do_deposit(chain, token, staking, address, amount):
    # initial = staking.call({'from': address}).deposited(amount)
    chain.wait.for_receipt(
        token.transact({'from': address}).approve(staking.address, amount))
    chain.wait.for_receipt(
        staking.transact({'from': address}).deposit(amount))
    # assert initial + amount == staking.call({'from': address}).deposited(amount)

def do_withdraw(token, staking, address):
    free_tokens = token.call().balanceOf(address)
    amount = staking.call({'from': address}).deposited(amount)
    staking.transact({'from': address}).withdraw()
    assert 0 == staking.call({'from': address}).deposited(amount)
    assert amount+free_tokens == token.call().balanceOf(address)

def test_empty_validators(chain, staking):
    assert [] == staking.call().validators(chain.web3.eth.blockNumber)

def test_deposit_and_immediate_withdraw(token, staking, accounts):
    do_deposit(token, staking, accounts[1], utils.denoms.ether)
    do_withdraw(token, staking, accounts[1])
    
def test_cant_withdraw_zero(token, staking, accounts):
    do_deposit(token, staking, accounts[1], utils.denoms.ether)
    
    # someone else can't withdraw
    with pytest.raises(TransactionFailed):
        staking.transact({'from': accounts[2]}).withdraw()
        
    # if I withdrew, I can't withdraw more
    do_withdraw(token, staking, accounts[1])
    with pytest.raises(TransactionFailed):
        staking.transact({'from': accounts[1]}).withdraw()

def test_deposit_join_withdraw_single_validator(chain, accounts, staking, token):
    addr = accounts[1]
    do_deposit(chain, token, staking, addr, utils.denoms.ether)
    staking.transact({'from': addr}).join()
    # not a validator yet
    assert [] == staking.call().validators(chain.web3.eth.blockNumber)
    
    # can't withdraw after joining
    with pytest.raises(TransactionFailed):
        chain.wait.for_receipt(
            staking.trasact({'from': addr}).withdraw())
            
    # can't withdraw while validating
    # become a validator (time passes)
    validating_epoch_start = staking.call().startBlock() + staking.call().epochLength()
    jump_to_block(chain, validating_epoch_start)
    # check if you are a validator
    assert [] != staking.call().validators(chain.web3.eth.blockNumber)
    with pytest.raises(TransactionFailed):
        chain.wait.for_receipt(
            staking.trasact({'from': addr}).withdraw())    
            
    # can't withdraw after validating, but before unbonding
    # wait until the end of the epoch
    validating_epoch_end = staking.call().startBlock() + 2 * staking.call().epochLength()
    jump_to_block(chain, validating_epoch_end)
    # make sure you are no longer a validator
    assert [] == staking.call().validators(chain.web3.eth.blockNumber)
    # fail while attempting to withdraw token which is still bonded
    with pytest.raises(TransactionFailed):
        chain.wait.for_receipt(
            staking.trasact({'from': addr}).withdraw())
    
    # withdraw after unbonding
    # wait until the unbonding period
    unbonding_period_end = staking.call().startBlock() + 3 * staking.call().epochLength()
    jump_to_block(chain, unbonding_period_end)
    # now withdraw should work
    do_withdraw(token, staking, addr)
    
def test_cant_join_outside_join_window(chain, token, staking, accounts):
    epoch_length = staking.call().epochLength()
    maturity_margin = staking.call().maturiyMargin()
    jump_to_block(chain, epoch_length-maturity_margin+1)
    with pytest.raises(TransactionFailed):
        chain.wait.for_receipt(
            do_deposit(token, staking, accounts[1], utils.denoms.ether))
    
def test_deposit_join_many_validators(chain, staking, token, accounts):
    for addr in accounts:
        do_deposit(token, staking, addr, utils.denoms.ether)
        chain.wait.for_receipt(
            staking.transact({'from': addr}).join())
    
def test_ejects_smallest_validators(chain, staking, token, accounts):
    ejected = staking.call().maxNumberOfValidators() < length(accounts)
    assert ejected > 0
    for idx, addr in enumerate(accounts):
        do_deposit(token, staking, addr, idx * utils.denoms.finney)
        chain.wait.for_receipt(
            staking.transact({'from': addr}).join())
    validators = staking.call().validators()
    for addr in accounts[:ejected]:
        assert addr not in validators
    
def test_cant_enter_if_too_small(chain, staking, token, accounts):
    address = accounts[1]
    # too small must be defined to be at least 1 wei
    amount = utils.denoms.wei
    chain.wait.for_receipt(
        token.transact({'from': address}).approve(staking.address, amount))
    chain.wait.for_receipt(
        staking.transact({'from': address}).deposit(amount))
    with pytest.raises(TransactionFailed):
        staking.transact({'from': address}).join()
    
def test_deposits_accumulate_for_join(chain, staking, token, accounts):
    addr = accounts[1]
    do_deposit(token, staking, addr, utils.denoms.finney)
    do_deposit(token, staking, addr, utils.denoms.finney)
    # chain.wait.for_receipt(
    #    staking.transact({'from': addr}).join()
    #assert [(_, 2*utils.denoms.finney)]
    
    
def test_deposits_accumulate_for_withdraw():
    pass
    
def test_join_does_continue_in_validating_epoch():
    pass

def test_eject_continueing_withdraws_work():
    pass
    
def test_can_withdraw_from_old_epoch():
    pass
    
def test_can_lookup_validators_from_the_past():
    pass
    

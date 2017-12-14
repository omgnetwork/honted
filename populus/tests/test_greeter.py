import json
import sys

import ethereum
from ethereum import tester, utils
import pytest
from populus.wait import Wait
from ethereum.tester import TransactionFailed

from ethereum.tester import TransactionFailed

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
                                                       deploy_args=[20, 2, token.address, 5])
    return staking

def jump_to_block(chain, block_no):
    # current_block = chain.web3.eth.getBlock('latest').number
    current_block = chain.web3.eth.blockNumber
    assert current_block < block_no
    chain.rpc_methods.evm_mine(block_no - current_block)
    assert chain.web3.eth.blockNumber == block_no

def get_validators(staking, epoch):
    result = []
    for i in range(0, sys.maxsize**10):
        validator = staking.call().validatorSets(epoch, i)
        owner = validator[2]
        if owner == zero_address():
            break
        result.append(tuple(validator))
    return result

def zero_address():
    return '0x0000000000000000000000000000000000000000'

def do_deposit(chain, token, staking, address, amount):
    initial = staking.call().deposits(address, 0)
    chain.wait.for_receipt(
        token.transact({'from': address}).approve(staking.address, amount))
    chain.wait.for_receipt(
        staking.transact({'from': address}).deposit(amount))
    assert initial + amount == staking.call().deposits(address, 0)

def do_withdraw(chain, token, staking, address, epoch = 0):
    free_tokens = token.call().balanceOf(address)
    amount = staking.call().deposits(address, epoch)
    staking.transact({'from': address}).withdraw(epoch)
    assert 0 == staking.call().deposits(address, epoch)
    assert amount + free_tokens == token.call().balanceOf(address)

def test_empty_validators(chain, staking):
    assert [] == get_validators(staking, 0)

def test_deposit_and_immediate_withdraw(chain, token, staking, accounts):
    do_deposit(chain, token, staking, accounts[1], utils.denoms.ether)
    do_withdraw(chain, token, staking, accounts[1])
    
def test_cant_withdraw_zero(chain, token, staking, accounts):
    do_deposit(chain, token, staking, accounts[1], utils.denoms.ether)
    
    # someone else can't withdraw
    with pytest.raises(TransactionFailed):
        staking.transact({'from': accounts[2]}).withdraw(0)
        
    # if I withdrew, I can't withdraw more
    do_withdraw(chain, token, staking, accounts[1])
    with pytest.raises(TransactionFailed):
        staking.transact({'from': accounts[1]}).withdraw(0)

def test_deposit_join_withdraw_single_validator(chain, accounts, staking, token):
    addr = accounts[1]
    do_deposit(chain, token, staking, addr, utils.denoms.ether)
    print(staking.call().startBlock())
    print(chain.web3.eth.blockNumber)
    print(staking.call().getCurrentEpoch())
    print(staking.call().getNextEpochBlockNumber())
    print(staking.call().getNewValidatorPosition(0))
    staking.transact({'from': addr}).join(addr)
    # not a validator yet
    # can't withdraw after joining
    for epoch in range(0, staking.call().getCurrentEpoch() + 1 + staking.call().unbondingPeriod()):
        with pytest.raises(TransactionFailed):
            chain.wait.for_receipt(
                staking.transact({'from': addr}).withdraw(epoch))
            
    # can't withdraw while validating
    # become a validator (time passes)
    validating_epoch_start = staking.call().startBlock() + staking.call().epochLength()
    jump_to_block(chain, validating_epoch_start)
    for epoch in range(0, staking.call().getCurrentEpoch() + 1 + staking.call().unbondingPeriod()):
        with pytest.raises(TransactionFailed):
            chain.wait.for_receipt(
                staking.transact({'from': addr}).withdraw(epoch))
            
    # can't withdraw after validating, but before unbonding
    # wait until the end of the epoch
    validating_epoch_end = staking.call().startBlock() + 2 * staking.call().epochLength()
    jump_to_block(chain, validating_epoch_end)
    # fail while attempting to withdraw token which is still bonded
    for epoch in range(0, staking.call().getCurrentEpoch() + 1 + staking.call().unbondingPeriod()):
        with pytest.raises(TransactionFailed):
            chain.wait.for_receipt(
                staking.transact({'from': addr}).withdraw(epoch))
    
    # withdraw after unbonding
    # wait until the unbonding period
    unbonding_period_end = staking.call().startBlock() + 3 * staking.call().epochLength()
    jump_to_block(chain, unbonding_period_end)
    # now withdraw should work
    do_withdraw(chain, token, staking, addr, staking.call().getCurrentEpoch())
    
def test_cant_join_outside_join_window(chain, token, staking, accounts):
    epoch_length = staking.call().epochLength()
    maturity_margin = staking.call().maturityMargin()
    jump_to_block(chain, epoch_length-maturity_margin+1)
    address = accounts[1]
    initial = staking.call().deposits(address)
    amount = utils.denoms.ether
    chain.wait.for_receipt(
        token.transact({'from': address}).approve(staking.address, amount))
    chain.wait.for_receipt(
        staking.transact({'from': address}).deposit(amount))
    assert initial + amount == staking.call().deposits(address)
    with pytest.raises(TransactionFailed):
        chain.wait.for_receipt(
            staking.transact({'from': address}).join(address))
    
def test_deposit_join_many_validators(chain, staking, token, accounts):
    max = staking.call().maxNumberOfValidators()
    for addr in accounts[:max]:
        do_deposit(chain, token, staking, addr, utils.denoms.ether)
        chain.wait.for_receipt(
            staking.transact({'from': addr}).join(addr))
    
def test_ejects_smallest_validators(chain, staking, token, accounts):
    ejected = staking.call().maxNumberOfValidators() < len(accounts)
    assert ejected > 0
    for idx, addr in enumerate(accounts):
        print("join ", idx, addr)
        do_deposit(chain, token, staking, addr, (idx+1) * utils.denoms.finney)
        chain.wait.for_receipt(
            staking.transact({'from': addr}).join(addr))
    validators = get_validators(staking, 0)
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
        staking.transact({'from': address}).join(address)
    
def test_deposits_accumulate_for_join(chain, staking, token, accounts):
    addr = accounts[1]
    do_deposit(chain, token, staking, addr, utils.denoms.finney)
    do_deposit(chain, token, staking, addr, utils.denoms.finney)
    chain.wait.for_receipt(
       staking.transact({'from': addr}).join(addr))
    validators = get_validators(staking, 0)
    print(validators)
    assert len(validators) == 1
    stake, _, owner = validators[0]
    assert stake == 2*utils.denoms.finney
    assert owner == addr
    
    
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
    
def test_correct_duplicate_join_of_a_single_validator():
    pass
    
def test_validator_can_continue_with_a_small_addition_to_stake():
    pass
    
    

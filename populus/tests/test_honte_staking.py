import json
import sys

from ethereum import utils
from ethereum.tester import TransactionFailed
import pytest
from populus.wait import Wait

from omg_contract_codes import OMGTOKEN_CONTRACT_ABI, OMGTOKEN_CONTRACT_BYTECODE

LARGE_AMOUNT = utils.denoms.ether
MEDIUM_AMOUNT = 10000
SMALL_AMOUNT = 10
ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

#### HELPERS AND FIXTURES

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
    for validator in accounts:
        chain.wait.for_receipt(
            token.transact({'from': owner}).mint(validator, LARGE_AMOUNT))
    chain.wait.for_receipt(
        token.transact({'from': owner}).finishMinting())
    return token

@pytest.fixture()
def epoch_length():
    return 40

@pytest.fixture()
def maturity_margin():
    return 5

@pytest.fixture()
def max_validators():
    return 4

@pytest.fixture()
def staking(token, chain, accounts, epoch_length, maturity_margin, max_validators):
    staking, _ = chain.provider.get_or_deploy_contract('HonteStaking',
                                                       deploy_transaction={'from': accounts[0]},
                                                       deploy_args=[epoch_length,
                                                                    maturity_margin,
                                                                    token.address,
                                                                    max_validators])
    return staking


def jump_to_block(chain, to_block_no):
    current_block = chain.web3.eth.blockNumber
    assert current_block < to_block_no
    # the "-1" is here, because it will mine until `to_block_no - 1` which will make `to_block_no` the current block
    # that the next transaction will be "in"
    chain.web3.testing.mine(to_block_no - current_block - 1)
    assert chain.web3.eth.blockNumber == to_block_no - 1

def get_validators(staking, epoch):
    result = []
    for i in range(0, sys.maxsize**10):
        validator = staking.call().getValidator(epoch, i)
        owner = validator[2]
        if owner == ZERO_ADDRESS:
            break
        result.append(tuple(validator))
    return result


@pytest.fixture()
def do(chain, token, staking):

    # special class that operates on the deployed contracts from the fixtures
    # they check some basic facts about the state of contracts after successful transacting
    class Doer:

        # successful deposit (two steps!)
        def deposit(self, address, amount):
            initial = staking.call().deposits(address, 0)
            chain.wait.for_receipt(
                token.transact({'from': address}).approve(staking.address, amount))
            chain.wait.for_receipt(
                staking.transact({'from': address}).deposit(amount))
            assert initial + amount == staking.call().deposits(address, 0)

        # successful withdrawal
        def withdraw(self, address, epoch=0, expected_sum=None):
            free_tokens = token.call().balanceOf(address)
            amount = staking.call().deposits(address, epoch)
            staking.transact({'from': address}).withdraw(epoch)
            assert 0 == staking.call().deposits(address, epoch)
            assert amount + free_tokens == token.call().balanceOf(address)
            if expected_sum is not None:
                assert amount == expected_sum

        # successful join
        def join(self, address, tendermint_address=None):
            if tendermint_address is None:
                tendermint_address = address

            next_epoch = staking.call().getCurrentEpoch() + 1
            staking.transact({'from': address}).join(tendermint_address)
            assert address in [validator[2] for validator in get_validators(staking, next_epoch)]
            assert tendermint_address in [validator[1] for validator in get_validators(staking, next_epoch)]
            assert staking.call().deposits(address, 0) == 0  # sucked in all the fresh deposit
            withdraw_epoch = next_epoch + 1 + staking.call().unbondingPeriod()
            assert staking.call().deposits(address, withdraw_epoch) > 0  # actual value depends on conditions

    return Doer()


@pytest.fixture
def lots_of_staking_past(do, chain, staking, accounts):
    max_validators = staking.call().maxNumberOfValidators()
    validators = accounts[0:max_validators]

    # several epochs with stakers one after another
    for _ in range(5):
        for validator in validators:
            do.deposit(validator, MEDIUM_AMOUNT)
            do.join(validator)
        jump_to_block(chain, staking.call().getNextEpochBlockNumber())

#### TESTS

def test_empty_validators(chain, staking):
    assert [] == get_validators(staking, 0)

def test_deposit_and_immediate_withdraw(do, accounts):
    do.deposit(accounts[1], LARGE_AMOUNT)
    do.withdraw(accounts[1])

def test_cant_withdraw_zero(staking, do, accounts):
    do.deposit(accounts[1], LARGE_AMOUNT)

    # someone else can't withdraw
    with pytest.raises(TransactionFailed):
        staking.transact({'from': accounts[2]}).withdraw(0)

    # if I withdrew, I can't withdraw more
    do.withdraw(accounts[1])
    with pytest.raises(TransactionFailed):
        staking.transact({'from': accounts[1]}).withdraw(0)

def test_deposit_join_withdraw_single_validator(do, chain, staking, token, accounts):
    validator = accounts[1]
    do.deposit(validator, LARGE_AMOUNT)
    do.join(validator)
    full_bonded_range = range(0, staking.call().getCurrentEpoch() + 1 + staking.call().unbondingPeriod())
    # not a validator yet
    # can't withdraw after joining
    for epoch in full_bonded_range:
        with pytest.raises(TransactionFailed):
            staking.transact({'from': validator}).withdraw(epoch)

    # can't withdraw while validating
    # become a validator (time passes)
    validating_epoch_start = staking.call().startBlock() + staking.call().epochLength()
    jump_to_block(chain, validating_epoch_start)
    for epoch in full_bonded_range:
        with pytest.raises(TransactionFailed):
            staking.transact({'from': validator}).withdraw(epoch)

    # can't withdraw after validating, but before unbonding
    # wait until the end of the epoch
    validating_epoch_end = staking.call().startBlock() + 2 * staking.call().epochLength()
    jump_to_block(chain, validating_epoch_end)
    # fail while attempting to withdraw token which is still bonded
    for epoch in full_bonded_range:
        with pytest.raises(TransactionFailed):
            staking.transact({'from': validator}).withdraw(epoch)

    # withdraw after unbonding
    # wait until the unbonding period
    unbonding_period_end = staking.call().startBlock() + 3 * staking.call().epochLength()
    jump_to_block(chain, unbonding_period_end)
    # now withdraw should work
    do.withdraw(validator, staking.call().getCurrentEpoch())

def test_cant_join_outside_join_window(do, chain, staking, accounts):
    address = accounts[1]
    do.deposit(address, LARGE_AMOUNT)
    start_block = staking.call().startBlock()
    epoch_length = staking.call().epochLength()
    maturity_margin = staking.call().maturityMargin()

    for margin_block in range(maturity_margin):
        jump_to_block(chain, start_block + epoch_length - maturity_margin + margin_block)
        with pytest.raises(TransactionFailed):
            staking.transact({'from': address}).join(address)
    # can join right after, but for _next epoch_
    jump_to_block(chain, start_block + epoch_length + 1)
    do.join(address)
    assert get_validators(staking, 1) == []
    assert len(get_validators(staking, 2)) == 1

def test_deposit_join_many_validators(do, chain, staking, token, accounts):
    max_validators = staking.call().maxNumberOfValidators()
    for validator in accounts[:max_validators]:
        do.deposit(validator, LARGE_AMOUNT)
        do.join(validator)

def test_ejects_smallest_validators(do, chain, staking, token, accounts):
    max_validators = staking.call().maxNumberOfValidators()
    prior_validators = accounts[0:max_validators]
    smallest_validator = accounts[2]
    for idx, validator in enumerate(prior_validators):
        if validator != smallest_validator:
            do.deposit(validator, (idx + 1) * MEDIUM_AMOUNT)
        else:
            do.deposit(validator, SMALL_AMOUNT)

        do.join(validator)

    # ejecting
    new_validator = accounts[max_validators]
    new_amount = (max_validators + 1) * MEDIUM_AMOUNT
    do.deposit(new_validator, new_amount)

    do.join(new_validator)

    validators = get_validators(staking, 1)
    validators_addresses = [validator[2] for validator in validators]  # just the addresses
    assert len(validators) == max_validators
    assert smallest_validator not in validators_addresses
    assert (new_amount, new_validator, new_validator) in validators

def test_cant_enter_if_too_small_to_eject(do, staking, token, accounts):
    max_validators = staking.call().maxNumberOfValidators()

    # larger players
    for idx_validator in range(max_validators):
        validator = accounts[idx_validator]
        do.deposit(validator, LARGE_AMOUNT)
        do.join(validator)

    small_validator = accounts[max_validators]
    small_amount = utils.denoms.wei
    do.deposit(small_validator, small_amount)
    with pytest.raises(TransactionFailed):
        staking.transact({'from': small_validator}).join(small_validator)

def test_deposits_accumulate_for_join(chain, do, staking, token, accounts):
    validator = accounts[1]
    do.deposit(validator, utils.denoms.finney)
    do.deposit(validator, utils.denoms.finney)
    do.join(validator)
    validators = get_validators(staking, 1)
    assert len(validators) == 1
    stake, _, owner = validators[0]
    assert stake == 2 * utils.denoms.finney
    assert owner == validator

def test_deposits_accumulate_for_withdraw(do, token, accounts):
    validator = accounts[1]
    do.deposit(validator, utils.denoms.finney)
    do.deposit(validator, utils.denoms.finney)
    current = token.call().balanceOf(validator)
    do.withdraw(validator)
    assert current + 2 * utils.denoms.finney == token.call().balanceOf(validator)

def test_can_withdraw_from_old_epoch(do, lots_of_staking_past, chain, staking, token, accounts):
    validator = accounts[1]
    do.deposit(validator, MEDIUM_AMOUNT)
    do.join(validator)
    withdraw_epoch = staking.call().getCurrentEpoch() + 1 + staking.call().unbondingPeriod() + 1
    much_later = staking.call().startBlock() + 30 * staking.call().epochLength()
    jump_to_block(chain, much_later)
    # now withdraw should still work
    do.withdraw(validator, withdraw_epoch)

def test_can_lookup_validators_from_the_past(do, lots_of_staking_past, chain, staking, token,
                                             accounts):
    much_later = staking.call().startBlock() + 30 * staking.call().epochLength()
    jump_to_block(chain, much_later)
    # now old stakes should still be reachable
    for epoch in range(5):
        validators = get_validators(staking, epoch + 1)  # +1 because we were _joining_ in epochs 0 through 4
        assert len(validators) == staking.call().maxNumberOfValidators()
        for idx, validator in enumerate(validators):
            assert validator[0] == MEDIUM_AMOUNT * (epoch + 1)
            assert validator[1] == accounts[idx]
            assert validator[2] == accounts[idx]

def test_join_does_continue_in_validating_epoch(do, chain, staking, accounts):
    validator = accounts[0]
    do.deposit(validator, MEDIUM_AMOUNT)
    do.join(validator)
    jump_to_block(chain, staking.call().getNextEpochBlockNumber())
    do.join(validator)

    assert get_validators(staking, 1) == get_validators(staking, 2)

def test_can_bump_stake_in_continuing(do, chain, staking, accounts):
    validator = accounts[0]
    do.deposit(validator, MEDIUM_AMOUNT)
    do.join(validator)
    jump_to_block(chain, staking.call().getNextEpochBlockNumber())
    do.deposit(validator, SMALL_AMOUNT)
    do.join(validator)

    assert get_validators(staking, 1) == [(MEDIUM_AMOUNT, validator, validator)]
    assert get_validators(staking, 2) == [(MEDIUM_AMOUNT + SMALL_AMOUNT, validator, validator)]

def test_cant_continue_in_unbonding_epoch(do, chain, staking, accounts):
    validator = accounts[0]
    do.deposit(validator, MEDIUM_AMOUNT)
    do.join(validator)
    bonding_start = staking.call().getNextEpochBlockNumber() + staking.call().epochLength()
    for block in range(staking.call().unbondingPeriod() * staking.call().epochLength()):
        jump_to_block(chain, bonding_start + block)
        with pytest.raises(TransactionFailed):
            staking.transact({'from': validator}).join(validator)

def test_can_withdraw_after_successful_continuation(do, chain, staking, accounts):
    validator = accounts[0]
    do.deposit(validator, MEDIUM_AMOUNT)
    do.join(validator)
    jump_to_block(chain, staking.call().getNextEpochBlockNumber())
    do.deposit(validator, SMALL_AMOUNT)
    do.join(validator)

    withdraw_epoch = staking.call().getCurrentEpoch() + 1 + staking.call().unbondingPeriod() + 1
    withdraw_block = staking.call().startBlock() + withdraw_epoch * staking.call().epochLength()
    jump_to_block(chain, withdraw_block)

    do.withdraw(validator, withdraw_epoch, expected_sum=(MEDIUM_AMOUNT + SMALL_AMOUNT))

# we need simpler contract for approachable test - single validator
@pytest.mark.parametrize("epoch_length,maturity_margin,max_validators", [
    (20, 1, 1),
])
def test_sequential_ejects_on_continuation(do, chain, staking, accounts):
    validator1, validator2 = accounts[1:3]
    do.deposit(validator1, MEDIUM_AMOUNT)
    do.join(validator1)
    assert get_validators(staking, 1) == [(MEDIUM_AMOUNT, validator1, validator1)]

    # 1 continues to epoch 2
    jump_to_block(chain, staking.call().getNextEpochBlockNumber())
    do.join(validator1)

    assert get_validators(staking, 2) == [(MEDIUM_AMOUNT, validator1, validator1)]

    # 2 ejects 1
    do.deposit(validator2, 2 * MEDIUM_AMOUNT)
    do.join(validator2)
    assert get_validators(staking, 2) == [(2 * MEDIUM_AMOUNT, validator2, validator2)]

    # 1 ejects 2 back with joint force of 3 * MEDIUM_AMOUNT
    do.deposit(validator1, 2 * MEDIUM_AMOUNT)
    do.join(validator1)

    assert get_validators(staking, 2) == [(3 * MEDIUM_AMOUNT, validator1, validator1)]

    # 2 ejects 1 again with 4 * MEDIUM_AMOUNT
    do.deposit(validator2, 2 * MEDIUM_AMOUNT)
    do.join(validator2)

    assert get_validators(staking, 2) == [(4 * MEDIUM_AMOUNT, validator2, validator2)]

    # withdraws as they're supposed to be - 1 withdraws 3 * MEDIUM_AMOUNT first, then 2 withdraws his stake:
    withdraw_epoch1 = staking.call().getCurrentEpoch() + staking.call().unbondingPeriod() + 1
    withdraw_block1 = staking.call().startBlock() + withdraw_epoch1 * staking.call().epochLength()
    jump_to_block(chain, withdraw_block1)
    do.withdraw(validator1, withdraw_epoch1, expected_sum=(3 * MEDIUM_AMOUNT))

    # check if the ejecting validator still bonded here
    withdraw_epoch2 = withdraw_epoch1 + 1
    for block in range(1, staking.call().epochLength()):
        with pytest.raises(TransactionFailed):
            staking.transact({'from': validator2}).withdraw(withdraw_epoch2)
        jump_to_block(chain, withdraw_block1 + block)

    withdraw_block2 = staking.call().startBlock() + withdraw_epoch2 * staking.call().epochLength()
    jump_to_block(chain, withdraw_block2)
    do.withdraw(validator2, withdraw_epoch2, expected_sum=(4 * MEDIUM_AMOUNT))

@pytest.mark.parametrize("epoch_length,maturity_margin,max_validators", [
    (20, 1, 1),
])
def test_can_withdraw_after_ejected_in_non_continuation(do, chain, staking, accounts):
    validator1, validator2 = accounts[1:3]
    do.deposit(validator1, MEDIUM_AMOUNT)
    do.join(validator1)

    # 2 ejects 1
    do.deposit(validator2, 2 * MEDIUM_AMOUNT)
    do.join(validator2)
    assert get_validators(staking, 1) == [(2 * MEDIUM_AMOUNT, validator2, validator2)]

    # 1 can withdraw immediately
    do.withdraw(validator1, expected_sum=MEDIUM_AMOUNT)

def test_correct_duplicate_join_of_a_single_validator(do, chain, staking, accounts):
    validator = accounts[1]
    do.deposit(validator, MEDIUM_AMOUNT)
    do.join(validator)
    do.deposit(validator, 2 * MEDIUM_AMOUNT)
    do.join(validator)

    validators = get_validators(staking, 1)
    # no duplicates
    assert len(validators) == 1
    # accumulated stake
    assert validators == [(3 * MEDIUM_AMOUNT, validator, validator)]

@pytest.mark.parametrize("epoch_length,maturity_margin,max_validators", [
    (40, 5, 2),
])
def test_late_comming_validator_ejects_by_continuing(do, chain, staking, accounts):
    validator1, validator2, validator3 = accounts[1:4]
    # 1 and 2 take epoch 1
    do.deposit(validator1, MEDIUM_AMOUNT)
    do.join(validator1)
    do.deposit(validator2, MEDIUM_AMOUNT)
    do.join(validator2)

    # 1 and 3 take epoch 2
    jump_to_block(chain, staking.call().getNextEpochBlockNumber())
    do.deposit(validator3, MEDIUM_AMOUNT)
    do.join(validator1)
    do.join(validator3)
    assert get_validators(staking, 2) == [(MEDIUM_AMOUNT, validator1, validator1),
                                          (MEDIUM_AMOUNT, validator3, validator3)]

    # 2 ejects by continueing
    do.deposit(validator2, SMALL_AMOUNT)
    do.join(validator2)
    assert get_validators(staking, 2) == [(MEDIUM_AMOUNT + SMALL_AMOUNT, validator2, validator2),
                                          (MEDIUM_AMOUNT, validator3, validator3)]

    # sanity check: epoch 1 unaffected still
    assert get_validators(staking, 1) == [(MEDIUM_AMOUNT, validator1, validator1),
                                          (MEDIUM_AMOUNT, validator2, validator2)]

@pytest.mark.parametrize("epoch_length,maturity_margin,max_validators", [
    (40, 5, 2),
])
def test_cant_eject_with_equal_deposit(do, chain, staking, accounts):
    validator1, validator2, validator3 = accounts[1:4]

    do.deposit(validator1, MEDIUM_AMOUNT)
    do.join(validator1)
    do.deposit(validator2, MEDIUM_AMOUNT)
    do.join(validator2)
    do.deposit(validator3, MEDIUM_AMOUNT)
    with pytest.raises(TransactionFailed):
        staking.transact({'from': validator3}).join(validator3)

def test_cant_join_with_bad_tendermint_address(do, chain, staking, accounts):
    validator = accounts[1]
    do.deposit(validator, SMALL_AMOUNT)

    with pytest.raises(TransactionFailed):
        staking.transact({'from': validator}).join(ZERO_ADDRESS)

    # sanity - correct staking works
    do.join(validator, tendermint_address=validator)

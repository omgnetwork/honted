from populus import Project
# from populus.wait import Wait
from populus.utils.wait import wait_for_transaction_receipt
import ethereum
from ethereum import tester, utils
import json
from omg_token_bytecode import OMGTOKEN_CONTRACT_ABI, OMGTOKEN_CONTRACT_BYTECODE

with open("populus/build/contracts.json") as f:
    contracts = json.loads(f.read())
    HONTE_STAKING_ABI = json.dumps(contracts['HonteStaking']['abi'])
    HONTE_STAKING_BYTECODE = contracts['HonteStaking']['bytecode']

def deploy(chain, ContractClass, owner):
    print("ContractClass: ", ContractClass)
    deploy_tx = ContractClass.deploy({"from": owner})
    # Wait(chain, chain.web3).for_receipt(deploy_tx)
    wait_for_transaction_receipt(chain.web3, deploy_tx)
    deploy_receipt = chain.web3.eth.getTransactionReceipt(deploy_tx)
    return ContractClass(address=deploy_receipt['contractAddress'])

def deploy_token(chain, owner):
    contract_class = chain.web3.eth.contract(abi=json.loads(OMGTOKEN_CONTRACT_ABI),
                                             bytecode=OMGTOKEN_CONTRACT_BYTECODE)
    token = deploy(chain, contract_class, owner)
    for i in range(2):
        addr = chain.web3.personal.newAccount(password())
        print("addr ", i, " ", addr)
        wait_for_transaction_receipt(chain.web3,
            token.transact({'from': owner}).mint(addr, utils.denoms.ether))
        print("mint ", i)
    wait_for_transaction_receipt(chain.web3,
        token.transact({'from': owner}).finishMinting())
    print("done minting")
    return token

def deploy_staking(chain, token, owner):
    contract_class = chain.web3.eth.contract(abi=json.loads(HONTE_STAKING_ABI),
                                             bytecode=HONTE_STAKING_BYTECODE)

    deploy_tx = contract_class.deploy({"from": owner}, args=[20, 2, token.address, 5])
    wait_for_transaction_receipt(chain.web3, deploy_tx)
    deploy_receipt = chain.web3.eth.getTransactionReceipt(deploy_tx)
    print("staking receipt: ", deploy_receipt)
    return contract_class(address=deploy_receipt['contractAddress'])

def get_default_account(chain):
    acc = chain.web3.eth.accounts[0]
    print("account: ", acc)
    return acc

def unlock(chain, acc):
    r = chain.web3.personal.unlockAccount(acc, password())
    print("unlock: ", r)
    return r

def password():
    return "this-is-not-a-secure-password"

def main():
    chainname = "temp"
    project = Project("populus")
    with project.get_chain(chainname) as chain:
        acc = get_default_account(chain)
        print("chain is ", chain)
        unlock(chain, acc)
        token = deploy_token(chain, acc)
        deploy_staking(chain, token, acc)

if __name__ == "__main__":
    main()

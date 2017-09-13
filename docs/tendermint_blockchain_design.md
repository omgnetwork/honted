# Tendermint Blockchain Design for Honte

This document will become a detailed description of how we are going to leverage the Tendermint consensus engine for **`honted`** - the blockchain node that will become the first decentralized ledger and exchange for OmiseGo.

We will refer to the Tendermint-based network as Honte-OmiseGO to avoid confusion.
Whenever a statement applies to OmiseGO in general, we'll use just "OmiseGO".

## Overview

The Honte-OmiseGO network will be a PoS-like network running on top of Tendermint consensus engine and Ethereum mainnet.
The consensus rules will be driven by Tendermint, the validator set and voting will be chosen based on status of a particular Ethereum smart contract (**Honte-OmiseGO contract**).
The consensus rules will be coded as an implementation of the ABCI interface (**`honted` ABCI app**), that the Tendermint engine talks to.

The `honted` ABCI app is going to be responsible for the following:
  - check transaction correctness
  - apply correct transactions to the state
  - tell the Tendermint consensus engine the validator set changes
  - apply no-transaction state transition to the state (will be made clear later on)
  - in particular, payout fees and perform _soft-slashing_ (will be made clear later on)

The first two are a straightforward implication of how Tendermint (ABCI) works the latter are a little less standard and will be explored in detail in subsequent sections.

### `honted` ABCI app state

The state that the application will manage (and distribute per Tendermint) consists of the following items (among other, TODO: make list exhaustive):
  - token registry
  - ledger - balances of addresses for the tokens
  - order book
  - fee pots - pools of funds that are going to be paid out to validators, unless they misbehave

## Validator set

In Tendermint consensus, the validator set is a mapping `pub_address => voting_power`, which determines, how much influence over blocks a particular validator has.
The validator set is managed by the Tendermint core, based on inputs the `honted` ABCI app will deliver in `EndBlock` calls.
In other words, every time Tendermint informs `honted` ABCI app that a block has ended, it expects to get changes to the validator set in return.

### PoS-like consensus and soft-slashing

As a general concept, the Honte-OmiseGO network will run a proof-of-stake consensus, with the modification of how slashing (penalizing attempts to derail consensus) works.

The PoS will use OMG tokens (on the Ethereum mainnet) as bond that allows to become an Honte-OmiseGO validator and earn fees.

We introduce a term **"soft-slashing"** which means, that in the event of (proven) misbehaviour of a validator, validator's stake (OMG on Ethereum) isn't taken away.
Only a substantial portion (whole?) of validator's hard-earned fees is taken away.
This means that regardless of behaviour, each validator will reclaim its bonded OMGs after a certain period of time.
The validator only risks losing the time-value of the bonded OMGs.

### Determining the validator set

From one Honte-OmiseGO block to another the validator set doesn't change by default.
There are two conditions, on which the validator set will change:

  - proven transition from one **epoch** to another.
  By epoch we mean a range of Ethereum blocks, where the OMG bonds aren't allowed to change
  An epoch should be thought of to be of the order of magnitude of months
  - soft-slashing

#### Changing the validator set on epochs

Each epoch will have a sub-range of Ethereum blocks called the join window.
**Join window** begins with every epoch and lasts for the length of epoch minus the finality margin.
**Finality margin** should be thought of as the number of blocks which need to pass for a block to be considered final.

At the end of every join window we specify an Ethereum block height **validator block**.

During the join/exit window OMG holders are allowed to bond and unbond their OMGs into the **Honte-OmiseGO contract**.
At validator block, the bonds are considered to be "locked in" to be effective and determine the validator set in the upcoming epoch.

TODO: ensure the next works

After the validator block is seen, the Tendermint block proposer should alter the validator set accordingly.
To do that we employ the **PoW finality proof**.
Such proposer should enclose the proof-of-work ranging from previous validator block (as embedded in `honted` ABCI app's state) to block **finality margin** blocks ahead of **validator block**.
Proposer thereby attest to having seen enough confirmations of the **validator block**.
This is necessary to prevent disputes and synchronization failures around the accessibility of Ethereum blocks.

TODO: diagram needed

The epoch change resets all validator changes arising from soft-slashing.

The amount of voting power every validator gets is equal to the amount of OMG bonded.

#### Changing the validator set on soft-slashing

Any validator that attempts to damage the consensus should be removed from the validator set until the end of the epoch.

## No-transaction state transition

The `honted` ABCI app state makes transitions on transactions sent by peers but also there is a canonical set of state transitions that **must** be made by the block proposer on every block.
Failure to do the state transition in a canonical manner (i.e. obtaining the same result as other validators) should result in soft-slashing.

The input state to the state transition is always the state on the preceeding (commited) block, and should be recognized on the `BeginBlock` call to the `honted` ABCI app (from Tendermint core)

The state transition will be performed in the `BeginBlock` too.
The output state of the state transition is a state that should be digested to a hash and embedded in the block being proposed.
Due to the canonicalization of the state transition, every validator should be able to provably verify correctness of the state transition

The scope and order of the no-transaction state transition is (TODO: make list exhaustive):

  - update validator set on new epoch
  - payout fee pots after end of old epoch
  - order book: timeouts - old orders should be removed after timeout Tendermint block height
  - order book: cancellation - canceled orders should be removed after cancellation block height
  - order book: matching - batch matching should be performed according to (TODO full specs).
  In a nutshell:
    - only orders after their timein may match. The reason to explicitly have timein and defer all matching to in-between blocks (i.e. to no-tx state transitions) is limit the manipulability of matching by the validators
    - the crossed pool of liquidity is determined and it all crosses at VWAP
    - orders might be partially filled (TODO: rethink: only one partially matched order possible every batch matching?)

**NOTE:** additions to the order book, soft-slashing proofs are transaction state transitions

## Fee structure

The fees are paid on transaction send in any token available on Honte-OmiseGO
(**NOTE** that the fees aren't paid or claimed in OMG on Ethereum!).

A **fee pot** is a special account that is specific to a particular `public address` and a particular epoch.
To illustrate that, in `honted` ABCI app's state one will have entries like (exact structure pending):
  - `balance/<token>/<public address>` - normal spendable balance of `public address`
  - `feepot/<token>/<epoch>/<public address>` - balance spendable after `epoch` has ended

Every fee is split and credited to fee pots according to:
  - **`proposer share`** - to proposer's fee pot
  - **`validator share`** (` == 100% - proposer share`) - to all (non-slashed) validators, proportionate to validators' powers

Whenever a validator is soft-slashed, all its fee pots are zeroed.
It is expected that all validators will pay out their fee pots to regular accounts.

## Soft-slashing conditions

As mentioned before, the effect of every correct soft-slashing is twofold:
  - removal from the validator set
  - forfeiture of all fees accumulated in the fee pot

The conditions on which soft-slashing occurs are multiple:
  - double-signing

    Proven with (TODO)

  - proposing a block with an invalid transaction

    Proven with (TODO)

  - invalid no-tx state transition

    Proven with (TODO)

# un-edited dumps from the meeting

## AML-KYC cert (TODO)

For a token like USD-backed token there will be requirements to KYC on-chain holders of the token.
The issuer should specify aml-kyc authority address for such a token.
aml-kyc authority address has the power to register (and unregister) other addresses as kyc-ed.
the ledger restricts the ability to hold the token only to registered addresses.
This is important for the phase when users can reclaim custody of the tokens on-chain.

TODO: what if address is unregistered and has tokens?

## chain naming (TODO)

domain-like system both for Plasma and Honte-OmiseGO

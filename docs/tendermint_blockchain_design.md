# Tendermint Blockchain Design for Honte

This document will become a detailed description of how we are going to leverage the Tendermint consensus engine for **`honted`** - the blockchain node that will become the first decentralized ledger and exchange for OmiseGo.

We will refer to the Tendermint-based network as Honte-OmiseGO to avoid confusion.
Whenever a statement applies to OmiseGO in general, we'll use just "OmiseGO".

## Overview

The Honte-OmiseGO network will be a PoS-like network running on top of Tendermint consensus engine and Ethereum mainnet.
The consensus rules will be driven by Tendermint, the validator set and voting powers will be chosen based on status of a particular Ethereum smart contract (**Honte-OmiseGO contract**).
How that happens, will be coded as part of the ABCI implementation (**`honted` ABCI app**), that the Tendermint engine talks to.

The `honted` ABCI app is going to be responsible for the following:
  - check transaction correctness
  - apply correct transactions to the state
  - tell the Tendermint consensus engine the validator set changes
  - apply `BeginBlock` state transition to the state (will be made clear later on)
  - in particular, payout fees and perform _soft-slashing_ (will be made clear later on)

The first two are a straightforward implication of how Tendermint (ABCI) works the latter are a little less standard and will be explored in detail in subsequent sections.

As an addition to the Tendermint consnsus, there is a necessity of having an **issuer's signoff** mechanism.
Regardless of the validator set, for every token issued, its issuer should sign off blocks which they find finalized.
Only after such signoff should the account balances and transactions involving that token be considered final.
See below for details

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

Each epoch will have a sub-range of Ethereum blocks called the join/exit window.
**Join/exit window** begins with every epoch and lasts for the length of epoch minus the maturity margin.
**Maturity margin** should be thought of as the number of Ethereum blocks which need to pass for a block to be considered mature (final),
for the sake of changing of validator set.

At the end of every join/exit window we specify a specific Ethereum block height called the **validator block**.

**NOTE** an alternative is to fix the validator block to be a first block after a specific point in time,
not a specific Ethereum block height.
Then everyone (and the **Honte-OmiseGO contract**) needs to calculate the respective block heights (epochs, join/exit windows) based on that.
**TODO**: analyze which approach is easier/more natural.

During the join/exit window OMG holders are allowed to bond and unbond their OMGs into the **Honte-OmiseGO contract**.
At validator block, the bonds are considered to be "locked in" to be effective and determine the validator set in the upcoming epoch.
The unbonded OMG tokens are spendable after some additional amount of time had passed,
call that the **unbonding period**.

After the validator block is seen, any node can call to alter the validator set accordingly in an **epoch change transaction**.
To do that we employ the **PoW maturity proof**.
Such epoch change transaction should hold the proof-of-work ranging from previous validator block (as embedded in `honted` ABCI app's state) to a block ahead of **validator block** by the **maturity margin**.
Sender of the epoch change transaction thereby provably attests to being witness of enough confirmations of the **validator block** on the Ethereum blockchain.
This attestation is necessary for all validators to unanimously agree on time, when the validators set should change.
This is necessary to prevent disputes and synchronization failures around the accessibility of Ethereum blocks.

[diagram](https://docs.google.com/drawings/d/1NHazCFyTx0iQuLLYu4dGmcJnP80GkpjL4Xm8r5JprJg/edit?usp=sharing)

The epoch change resets all validator changes arising from soft-slashing.

The amount of voting power every validator gets is equal to the amount of OMG bonded.

**NOTE**: the reason why validators would want to process the change (send and accept the epoch change transaction) at all is that
the payout of fee-pots is correlated with changing the validator set.
So in case that change implies relinquishing control, validators need to do it to claim earned fees.
Secondary reason is that failure to process the change could jeopardize value of bonded OMG tokens.

##### Example: edge case with validators disagreeing on Ethereum blockchain tip

A hypothetical edge case, that the PoW maturity proof prevents, is illustrated below:

Let's assume that:
  - an epoch begins at Ethereum block height 50
  - the maturity margin is 10 blocks (validator block is then block at height 40)

Proposer sees Ethereum block 50 mined and should process the validator set change,
setting the validator set to whatever is implied by the Honte-OmiseGO contract at height 40.
Another validator will see this processing happen, but it has only seen Ethereum block height 49,
so according to that the epoch has not yet begun.
Allowing for leeway in that validator's assessment ("everyone has seen block 50, maybe I should believe them") doesn't solve this.

##### PoW maturity proof - difficulty

The important consideration to take when checking the PoW maturity proof is the difficulty of the PoW being supplied.
The total difficulty of the supplied block headers,
that the PoW maturity proof consists of,
should be "adequate", i.e. it shouldn't be maliciously lowered to trick validators into processing the epoch change transaction too early.

The consequence of this is that the PoW maturity proof must include info sufficient to attesting that the difficulty has been calculated properly (probably some timestamps - TODO: investigate when time comes)

#### Changing the validator set on soft-slashing

Any validator that attempts to damage the consensus should be removed from the validator set until the end of the epoch.

## `BeginBlock` state transitions (formerly "no-tx state transitions")

The `honted` ABCI app state makes transitions on transactions sent by peers but also there is a canonical set of state transitions that **must** be made by the block proposer on every block.
Failure to do the state transition in a canonical manner (i.e. obtaining the same result as other validators) is considered benign byzantine behavior of proposer and should result in ignoring the proposed block.

The input state to the state transition is always the state on the preceding (committed) block, and should be recognized on the `BeginBlock` call to the `honted` ABCI app (from Tendermint core).
`BeginBlock` state transitions are functions of `honted` ABCI app state, block height and validator set exclusively.
They may be thought of as cleansing (flushing) of the `honted` ABCI app state.

As the name suggests, such state transitions will be performed in the `BeginBlock` call to the `honted` ABCI app.
The output state of the state transition is a state that should be digested to a hash and embedded in the block being proposed (NOTE: this probably not necessary).
Due to the canonicalization of the state transition, every validator should be able to provably verify correctness of the state transition

The scope and order of the `BeginBlock` state transition is (TODO: make list exhaustive):

  - update validator set, based on changes determined by transactions (like epoch change transactions and soft-slashing transactions) - see NOTE 2 below
  - payout fee pots after end of old epoch
  - order book: timeouts - old orders should be removed after timeout Tendermint block height
  - order book: cancellation - canceled orders should be removed after cancellation block height
  - order book: matching - batch execution should be performed according to [matching and execution specs](docs/batch_matching.md).
  In a nutshell:
    - only orders after their timein may match. The reason to explicitly have timein and defer all matching to in-between blocks (i.e. to `BeginBlock` state transitions) is limit the manipulability of matching by the validators
    - the crossed pool of liquidity is determined and it all executes at VWAP
    - orders might be partially filled

**NOTE:** In contrast to the above, things like additions to the order book, soft-slashing proofs are _transaction_ state transitions.

**NOTE 2:** Updating of the validator set is a two-step process:
1. First an epoch change transaction (or soft-slashing) transaction is processed during `DeliverTx` call to `honted` ABCI app.
The result of that transaction is cached somewhere
2. Second there is a `EndBlock` state transition that consumes the cached result and updates the validator set in Tendermint.

## Fee structure

The fees are paid on transaction send in any token available on Honte-OmiseGO
(**NOTE** that the fees aren't paid or claimed in OMG on Ethereum!).

A **fee pot** is a special account that is specific to a particular `public address` and a particular epoch.
To illustrate that, in `honted` ABCI app's state one will have entries like (exact structure pending):
  - `balance/<token>/<public address>` - normal spendable balance of `public address`
  - `feepot/<token>/<epoch>/<public address>` - balance spendable after `epoch` has ended.
  That epoch should be the epoch that begins at least after the current one, i.e. each validator earns fees that will be spendable after at least one full epoch.
  This is a required delay that increases the value at stake for validators, i.e. misbehaving could lead them to lose fees earned in previous epoch.

Every fee is split and credited to fee pots according to:
  - **`proposer share`** - to proposer's fee pot
  - **`validator share`** (` == 100% - proposer share`) - to all (non-slashed) validators, proportionate to validators' powers

Whenever a validator is soft-slashed, all its fee pots are zeroed, the fees accumulated are redistributed to other validators (TODO: how exactly?).

Some portion of the accumulated and slashed fees should be burnt or distributed to someone different than validators.
This is required to make the overall result from soft-slashing a "negative outcome gain",
i.e. validators cannot collude to attempt to cheat for free.

It is expected that all validators will pay out their fee pots to regular accounts periodically to minimize risk.

There should be a possibility of setting fee equal to zero and specifying no (nil) token to pay fee in,
for any transaction.
This is required to allow to create the first token in a valid transaction.

## Soft-slashing conditions

As mentioned before, the effect of every correct soft-slashing is twofold:
  - removal from the validator set
  - forfeiture of all fees accumulated in the fee pot

The conditions on which soft-slashing occurs are multiple:
  - double-signing or other malfeasance in boundaries of Tendermint consensus

    Tendermint might provide tools to handle this, see:
      - https://github.com/tendermint/tendermint/issues/569
      - https://github.com/tendermint/tendermint/issues/338

    In general this should be detected by Tendermint.
    More or less `BeginBlock` would feed a list of misbehaving validators into the `honted` ABCI app.

    Otherwise handling of a "double-signing slashing condition" transaction would need to replicate Tendermint's consensus logic,
    to determine the legitimacy of a slashing condition submitted.
    Probably handling of this would need to be interactive (i.e. validator may defend by revealing some justification for a particular signature).
    Most likely quite hard.

  - proposing a block with an invalid transaction

    Tendermint might provide tools: see above

    This can be done in `DeliverTx` call to the `honted` ABCI app.
    At that stage, an invalid transaction should not have the effect it attempts to introduce.
    Also we might consider that instead of not having the effect it attempts to introduce,
    it may have the effect of slashing the proposer (assuming we do have proposer's address at this stage, see discussion in issues mentioned)

### Byzantine behaviour without soft-slashing

There are kinds of byzantine behaviour that cannot escalate and are easy to handle by the validators immediately.
As per [discussion](https://github.com/tendermint/tendermint/issues/679) with the Tendermint team,
it's enough that the 2/3 of honest validators reject such incorrect behaviour.

Kinds of byzantine behaviour that aren't slashing conditions:

  - invalid `BeginBlock` state transition

  No provisions to detect this the `honted` ABCI app.
  Block with an invalid state transition will not be voted on by the validators.
  No way of detecting this at this stage of Tendermint and according to the linked discussion, we don't need that

  The penalty for the proposer, that proposes such invalid block is the forfeiture of transaction fees.

## Issuer signoff

Every token issuer has the possibility to send a `SignOff` transaction indicating
  - block height
  - block hash

whereby the issuer attests the blockchain until the height and for the given chain branch (as indicated by the hash).
Any observer of the blockchain can then check,
if a particular transaction observed has been committed in the block that has been signed off.
It is assumed that the actor signing off will run a full `honted` observer node and periodically:
  - query the status of the node (basically check, if there are no breaches in the consensus, i.e. invalid transactions committed, incorrect state transitions)
  - create/sign/submit a `SignOff` transaction

It is also assumed that issuers of tokens will make their rules about signing off (e.g. "sign off every `N` blocks") public

**NOTE** - any address can sign off, not only issuer's address, but currently, signing off only has business value for issuers.
In particular, the sign off is bound to the issuer's address, and **not** the token itself.

The correctness of the height and hash isn't checked by the validators -
it doesn't make sense to, as the sign off is a mechanism to actually oversee the validators.

## Hard forks and staking limiting

Hard forks are considered as the last resort remedy against byzantine behavior of validators (e.g. halting the chain having bonded huge amount of OMG and claiming > 1/3 voting power).
The amount of OMG bondable might also be somewhat limited in the smart contract (e.g. only KYC'd stakers, ""**know-your-validator**""),
to prevent such possibility.
OmiseGO would take a trusted and privileged position in hard forks and the "know-your-validator" process.

## AML-KYC certification

For a token like USD-backed token there will be requirements to KYC on-chain holders of the token.
The issuer should specify **KYC address** for such a token, and this address should be in control of a suitable AML-KYC authority
KYC address has the power to register (and unregister) other addresses as KYC-ed.
The ledger, as part of transaction validity determined by `honted` ABCI app, restricts the ability to hold the token only to registered addresses.
This is important for the phase when users can reclaim custody of the tokens on-chain.

TODO: what if address is unregistered while holding tokens?

## Chain naming

Since both for Plasma blockchain (Tesuji milestone) and Honte-OmiseGO network there are possible many chains,
there needs to be a consistent naming scheme for these chains.
This will allow applications to refer to a particular chain.

The naming scheme is going to be:

`root_chain_id/chain_id/.../chain_id/chain_id/address`

Where address is the actual address, and `chain_id`s are the ids of the child chain on the parent chain.
Top-most `root_chain_id` should be the address of an Ethereum smart contract, identifying the eldest Plasma chain.

For the Honte-OmiseGO we restrict to single-tier equivalent:

`[root_chain_id]/address`

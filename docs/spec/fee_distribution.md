# Fee Distribution Specification

## Introduction

This document describes the fee distribution mechanism for HonteD, the 
decentralised exchange, which is a Plasma zone that implements IBC.

In the following paragraphs we describe the general fee distribution
architecture, followed by the economic reasoning for it and lastly we finish
with pseudo code in order to provide an implementation guide.

Normally a blockchain rewards its operators with two separate form of 
distribution. Firstly, the block provisions which are a socialisation of costs
of running the blockchain. It is a socialisation of costs since block
provisions effectively inflate the token supply. Secondly operators receive
transaction fees. These are a spam prevention mechanism and an incentive to 
participate in consensus. 

HonteD uses an exogenous validator set. For this application the validator set
is determined by a smart contract on Ethereum, the parent chain. Token holders
stake their OMG tokens on Ethereum into the smart contract and HonteD uses
the staking contract to determine the validator set. As a consequence it is
infeasible to give block provisions. As such HonteD only has transaction fees.


## Fee Distribution

Fees are distributed evenly between all validators. An extension to this is 
that the proposer of every block receives 5% extra fees if he includes 100%
of signatures from the rest of the validators. This creates a trade-off
between waiting for more signatures and timing out from the proposal round.
It incentives validators to create stronger connectivity between themselves
as well as helps to prevent censorship since it puts an economic cost on it.
// TODO: How to retrieve the block proposer and signatures for each block.
// Cosmos hub will do this and we can reuse the logic.

## TODO
* spec out the data structures to distribute the fees
* explain how users can withdraw fees by submitting proofs of delegation from
  Ethereum
* consider using the Plasma design to make the withdrawal easier
* ensure that it is of reasonable complexity

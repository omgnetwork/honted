# Frontrunning problem

## Scope

We care about frontrunning by miners, not frontrunning by any other participants of the network.

## Problem

Miner (block proposer) decides about the order of inclusion of transactions into the block. It can trivially sandwich large direct orders, extracting rent from his privileged position. This decreases value proposition of network to its users. The main source of the problem is the fact that miner is in possession of both knowledge and opportunity to front-run. Any solution to this problem should attack one of those assets of the miner while not transforming direct order into an option on futures contract.

## Solutions

### Bad solution

Commit order in encrypted form. After it is included in the order book, but before its execution, reveal it to allow the miner to properly process it. Why doesn't it work? Because it turns order into *option* - the user may choose not to reveal if circumstances are bad.

### Good solution - randomness beacon

There is a randomness beacon that publishes public key PKn on every block height n and corresponding private key Kn at block height n+k. Participants encrypt their market orders using public key and miners decrypt orders as soon as the private key is revealed. Why does this work? Because the user doesn't have an ability to not reveal the order anymore. Miner can't choose to not reveal the order or to not process the order - both operations can be a part of the consensus.

#### Strong sides

Does not require additional messages from a user. Does not require the user to be online to reveal the order. Does not require anonymity set for send txes to mask ones that might be in fact orders.

#### Weak sides

Construction of such randomness beacon that can be trusted not to collude with some of the miners to enable frontrunning is a problem in itself. Possible topic of further research - BLS (threshold) signatures for random number generation.

### Good solution - submarine send

For origin of the idea - see http://hackingdistributed.com/2017/08/28/submarine-sends/

Instead of sending order tx user sends send tx, where address field is a hash of order information. For this to work send txes should be processed just as orders are - with inclusion into order book and high latency. While such send is in order book user must reveal preimage of the address field in separate tx. When preimage is revealed, a miner can properly process the order. How is it different from commit-reveal scheme above? The user will lose funds if he will choose not to reveal or miners will not mine reveal tx. Why does this work? Because the user is strongly compelled to reveal - otherwise it will lose his money. And because miners can't censor order reveal since that would require all miners to collude.

#### Strong sides

Simple. Does not require additional interactive protocols nor creates a group or a point that can be attacked/compromised.

#### Weak sides

Requires anonymity set to hide submarine sends among real sends. Which are hard to produce since they need to be:

* high latency (same lifecycle as a direct market order)

* done to new addresses

First can be addressed by making those sends free or really cheap. The fee can be adjusted dynamically to make sure that anonymity set is large enough but not too large. The second one is trickier since new addresses are largely not very useful from the point of view of users and even worse than that - they grow consensus state if not handled in a special way.

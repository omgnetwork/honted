# Batch matching and execution for Honte-OmiseGO

**NOTE**: both drafts are obsolete: first is broken and second hasn't really been delivered.
FIXME: fix following link from posted in comments

## VWAP execution draft

We give a generic description of the expected batch matching done by the exchange.
We try to deliver it agnostic of the "centralized"/"decentralized" approach as well as Tendermint (Honte-OmiseGO network)/Plasma approach.

Assume we have a token pair `X/Y`.
There is no `Y/X` pair represented, so there needs to be an ordering between tokens.

There are defined moments in time where batch matching takes place.
At every instant we consider the order book - which is the set of orders which satisfy all of:

  - instant is between order's timein and timeout of order
  - are of `X/Y` pair, either on buy or sell side, i.e. (buy order is buy `X`, sell order is buy `Y`)
  
The price of `X/Y` is always quoted as number of units of `X` for `Y_denom` amount of units of `Y`.
The order amount is always in units of `X`.

Assume that the order book is composed of orders: `buy_1`, ..., `buy_n` and `sell_1`, ..., `sell_k`, each with respective price.

Let `buy_min` be the lowest buy (bid) price, and `sell_max` is the highest sell (ask) price.

Let `buy_crossed` by all buy orders with price lower or equal than `sell_max` and `sell_crossed` be all sell orders with price higher or equal than `buy_min`. 
Let `buy_X_volume` and `sell_X_volume` be the respective volumes of `X` of these orders and they have their `Y` counterparts, calculated based on the prices.

Pick **smaller** volume of these two and denote it as `crossed_volume` and those orders as `shallower_orders`.
This gives the amount of units of `X` that will be traded at this particular instant.
The side opposite to the `shallower_orders` is called `deeper_side`.

On the `deeper_side`, the best offers with the sum of amounts equal `crossed_volume` will cross.
One order there will execute partially.

All trades are executed at VWAP price (`execution_price`) calculated based on the `shallower_orders`.

The order on the `deeper_side` that got executed partially,
is submitted in it's unexecuted part back to the order book for the next instant.

All arithmetic is integer-based.
All operations must be deterministic.

### Example

`buy_3`: 100 `X`, at 50/100, 200 `Y`
`buy_2`: 130 `X`, at 40/100, 325 `Y`
`buy_1`: 30 `X`, at 30/100, 100 `Y`
`sell_1`: 40 `X`, at 45/100, 89 `Y`
`sell_2`: 60 `X`, at 35/100, 171 `Y`
`sell_3`: 100 `X`, at 25/100, 400 `Y`

`buy_min` is 30/100, `sell_max` is 45/100.

`buy_volume` is 160, `sell_volume` is 100, so `crossed_volume` is 100, `sell_1` and `_2` are shallower_orders.
Buy side is `deeper_side`

VWAP `execution_price` is 39/10. 100 `X` will be exchanged for 256 `Y`.

**^^^ ABANDONED ^^^, this doesn't seem to work, since VWAP price might be worse than the price set by an order**

**Alternative:**

## Iterative, best offer execution draft:

1. Sort buy and sell orders for the pair
  - primary key: price - best price comes first
  - secondary keys (TBD): timein, timeout, X volume, Y volume, random
2. Take first buy and sell orders, attempt to match
  - of no match - end matching
  - if matched, execute at the VWAP price of both orders' prices.
  One of the orders might match partially, the unmatched portion remains as the new first order
3. Goto 2.

**NOTE** since the execution price might be better than the order limit,
it is expected, that untraded tokens will be transferred back to seller's account.

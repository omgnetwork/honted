# Batch matching and execution for Honte-OmiseGO

## Iterative, best-offers-first batch execution draft:

Assume two currencies X and Y.
There are two separate order books for two inverse pairs: X/Y and Y/X.
(**NOTE**: There were attempts to have a single order book which would merge the "X/Y"- and "Y/X"-flavors of orders (aka "pivots"),
this was dubbed impossible and abandoned.)
Every order book holds limit orders:
  - X/Y order book holds "buy 100 X for at most 10 Y" and "sell 100 X for at least 10 Y" orders
  - Y/X order book holds "buy 10 Y for at most 100 X" and "sell 10 Y for at least 100 X" orders
  
Let's assume we're on X/Y pair, so Y is the base currency, prices are in Y for some unit of X.
At every discrete interval:

1. Sort buy and sell orders for the pair
    - primary key: price - best offered price comes first
    - secondary keys (TBD): timein, timeout, X volume
    - last resort sorting key: some deterministic, public and not-too-manipulable data (e.g. order of inclusion of transactions, perhaps?) in case primary/secondary
2. Take first buy and sell orders, attempt to match
    - of no match - end matching
    - if matched, mark for execution up to the amount of whichever order's X volume is lower. One of the orders might match partially, the unmatched portion remains as the new first order
3. Goto 2.
4. All orders marked for execution execute at the price equal to the mid-point between the last matched orders

### Lead-in, time-in, time-out of orders

Due to the decentralized nature of the order book, there needs to be a rule that constraints the timing of the orders.
The constraint is that the order submitter specifies 2 block height:
  - `time-in` - first block when the order is able to match
  - `time-out` - first block when the order is not able to match anymore
  
There is a consensus rule that prohibits an order placing transaction to be included in the block after `time-in - lead-in`.
`lead-in` interval is fixed as a consensus rule.

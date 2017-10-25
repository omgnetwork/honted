# Batch matching and execution for Honte-OmiseGO

## Iterative, best-offers-first-with-pivots execution draft:

We assume that every order specifies a pivot currency.
A "buy 100 X sell 10 Y, **Y pivot**" means that I want to sell 10 Y and get at least 100 X for that. 
A "buy 100 X sell 10 Y, **X pivot**" means that I want to buy 100 X and spend at most 10 Y for that.

There is an option to have the pivoting fixed for a X/Y pair, i.e. for X/Y always X is pivot.
The ability to choose the pivot with every order is a feature to be discussed.

1. Sort buy and sell orders for the pair
  - primary key: price - best price comes first
  - secondary keys (TBD): timein, timeout, X volume, Y volume, random
2. Take first buy and sell orders, attempt to match
  - of no match - end matching
  - if matched, execute at the mid price of both orders' prices. One of the orders might match partially, the unmatched portion remains as the new first order
  - the amount executed needs to satisfy the following conditions:
    - never exceed the amount sold. If an order sells 10 Y, execution never exceeds 10 Y
    - never exceed the amount bought, if token bought is the pivot
    - always attempt to sell all of token sold if token sold is the pivot
    - **NOTE:** for a non-pivot token, the execution of a single order can either  make buyer buy more of that token, or make seller sell less of that token
3. Goto 2.

**NOTE** since the execution price might be better than the order limit,
it is expected, that untraded tokens will be transferred back to seller's account immediately,
in case that order fills completely.

Examples of executions of a single pair of matched orders, depending on their pivots:
 - b1: `buy 100 X sell 10 Y, X pivot` vs s1: `sell 100 X buy 5 Y, X pivot`
 
   all 100 X is traded for mid-price of 7.5 Y. Both b1 and s1 get 2.5 Y discount and fill completely
   
 - b1: `buy 100 X sell 10 Y, Y pivot` vs s1: `sell 100 X buy 5 Y, Y pivot`
 
    66,666 X is traded for mid-price of 5 Y. s1 gets 33,333 X discount and fills completely, b1 continues to buy X
   
 - b1: `buy 100 X sell 10 Y, Y pivot` vs s1: `sell 100 X buy 5 Y, X pivot`
 
   all 100 X is traded for mid-price of 7.5 Y. s1 get's 2.5 Y discount and fills completely, b1 continues to sell Y
   
 - b1: `buy 10 X sell 1 Y, X pivot` vs s1: `sell 100 X buy 5 Y, Y pivot`
 
    10 X is traded for mid-price of 0.75 Y. b1 gets 0.25 Y discount and fills completely, s1 continues to buy Y
   
 More simulations at https://docs.google.com/spreadsheets/d/14l1Vps4YTaJQXk5xEVex3RcElBitCOALpIHhSW-YRs4/edit#gid=321398369.
 
 
   
## [OBSOLETE]] Performance tests using `tm-bench` - not saturated yet

**NOTE** the results are meaningless at current stage. Do not pass them on in **any** form.

Performance test is done using a script that:

 - starts Tendermint
 - starts our HonteD ABCI app
 - starts `tm-bench` a tool that listens to a Tendermint node and counts transactions and blocks
 - "floods" Tendermint with transactions

**tl;dr**

 - the saturation point not found yet due to inefficiency of our link to Tendermint

   to be fixed in https://phabricator.omisego.io/T415 using either
     - a persistent connection to the Tendermint RPC
     - doing https://phabricator.omisego.io/T148 (dependent transactions in a block)


### Simple case

```
$ mix run apps/honted_integration/scripts/performance.exs --nstreams 800 --fill-in 0 --duration 60
Stats             Avg        Stdev      Max     
Block latency     0.18ms     0.04ms     0ms     
Blocks/sec        0.932      0.251      1       
Txs/sec           333        188        500
```

### After some transactions

```
$ mix run apps/honted_integration/scripts/performance.exs --nstreams 800 --fill-in 5000 --duration 60
Stats             Avg        Stdev      Max     
Block latency     0.25ms     0.09ms     0ms     
Blocks/sec        0.898      0.354      2       
Txs/sec           326        190        500     
```

and if we cut out mock-hash generation (in `abci.ex`):
```
$ mix run apps/honted_integration/scripts/performance.exs --nstreams 800 --fill-in 5000 --duration 60
Stats             Avg        Stdev      Max     
Block latency     0.27ms     0.07ms     0ms     
Blocks/sec        0.932      0.312      2       
Txs/sec           424        161        500     
```

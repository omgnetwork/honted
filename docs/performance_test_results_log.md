## Commit: `3690d4268c306013f4516d981fb4b3945407996a`

```
mix run --no-start -e 'HonteD.PerftestScript.setup_and_run(5, 0, 100)'
```
(+ `%{profiling: ..., homedir_size: true}` optional argument, as needed.

Without the overhead of profiling, the txs processed (_Intel® Core™ i5-7200U CPU @ 2.50GHz × 4_, running _Ubuntu 16.04.3 LTS 64-bit_):
```
12:51:07.031 [info]  I[01-15|11:51:07.031] Executed block                               module=state height=2 validTxs=2025 invalidTxs=0
12:51:08.143 [info]  I[01-15|11:51:08.143] Executed block                               module=state height=3 validTxs=2131 invalidTxs=0
12:51:09.194 [info]  I[01-15|11:51:09.194] Executed block                               module=state height=4 validTxs=1952 invalidTxs=0
12:51:10.300 [info]  I[01-15|11:51:10.300] Executed block                               module=state height=5 validTxs=2039 invalidTxs=0
12:51:11.379 [info]  I[01-15|11:51:11.378] Executed block                               module=state height=6 validTxs=1975 invalidTxs=0
[SNIP!]
12:52:40.704 [info]  I[01-15|11:52:40.704] Executed block                               module=state height=90 validTxs=103 invalidTxs=0
12:52:41.816 [info]  I[01-15|11:52:41.815] Executed block                               module=state height=91 validTxs=142 invalidTxs=0
12:52:42.918 [info]  I[01-15|11:52:42.918] Executed block                               module=state height=92 validTxs=135 invalidTxs=0
12:52:44.052 [info]  I[01-15|11:52:44.052] Executed block                               module=state height=93 validTxs=125 invalidTxs=0
12:52:45.137 [info]  I[01-15|11:52:45.137] Executed block                               module=state height=94 validTxs=124 invalidTxs=0
```

(`tm-bench` output is borked due to: https://phabricator.omisego.io/T605)

**NOTE** the above result is for future reference only, do not cite!

### CPU load

1. Tesla's `'Elixir.HonteD.API.TendermintRPC',client,0}` isn't a burden: `286.370` out of `531801.077` in `{'Elixir.HonteD.API',submit_sync,1}`. Likely it only creates a function returning the client.
  - **NOTE** it has been removed in subsequent optimizations, now using persistent Websocket connection
2. in `{'Elixir.HonteD.API.TendermintRPC',broadcast_tx_sync,2}` mostly `Tesla` and `http` request handling
  - see NOTE above, not any more
3. `{'Elixir.HonteD.Performance.Scenario','-prepare_send_streams/4-fun-0-',5}` takes `2787.796` which is small but noticeable if compared to time spent with `ABCI`. Most of this is spent in creating and signing transactions (equal because both are mocks - hash functions)
6. After
   - changing `http` communication with Tendermint RPC to `websockets`
   - diversifying the receivers and making the state fill more

   the code handling transactions breaks down as follows (majority of time spent using our silly-state-hashing):
          { {'Elixir.HonteD.ABCI',handle_call,3},       12302,45333.018,  103.391},     %
          [{{'Elixir.HonteD.TxCodec',decode,1},         12152, 1448.985,   44.439},
           {{'Elixir.HonteD.ABCI',generic_handle_tx,2}, 12152, 3935.379,   43.704},
           {{'Elixir.HonteD.ABCI',code,1},              12202,   21.434,   21.434},
           {{'Elixir.HonteD.ABCI.Events',notify,2},     5478,  113.644,   11.457},
           {garbage_collect,                              17,    0.973,    0.973},
           {{'Elixir.HonteD.ABCI.State',hash,1},          50,39707.260,    0.347},
           {{'Elixir.List.Chars',to_charlist,1},          50,    1.952,    0.239}]}.
7. We seem to be at saturation point. There are no evident bottlenecks aside in the node itself
  - `{'Elixir.HonteD.API.TendermintRPC.Websocket','send!',3}` seems to do a lot of heavy lifting with JSON encoding.
  This should, however, not be a limiting factor for the test. **NOTE** consider changing to `Jason`,
  which claims to be faster. For reference:
         { {'Elixir.HonteD.API.TendermintRPC.Websocket','send!',3},2834, 5475.848,   20.509},     %
         [{{'Elixir.Socket.Web','send!',2},            2834, 1185.560,    8.866},      
          {{'Elixir.Poison','encode!',1},              2834, 4269.779,    8.282}]}.    

### Disk usage

Manually, using `sudo iotop -Pod 10`.
**NOTE** Only Tendermint's usage is measured, as only Tendermint persists data on disk.
Some arbitrary samples of disk usage:
```
  PID  PRIO  USER     DISK READ DISK WRITE>  SWAPIN      IO    COMMAND
24397 be/4 user        0.00 B/s    3.89 M/s  0.00 %  7.81 % tendermint --home /tmp/honted_tendermint_test_homedir-1516014162-24328-8fnvf5 --log_level *:info node
24397 be/4 user        0.00 B/s 1433.89 K/s  0.00 % 99.99 % tendermint --home /tmp/honted_tendermint_test_homedir-1516014162-24328-8fnvf5 --log_level *:info node
24397 be/4 user        0.00 B/s  990.11 K/s  0.00 % 96.64 % tendermint --home /tmp/honted_tendermint_test_homedir-1516014162-24328-8fnvf5 --log_level *:info node
24397 be/4 user        0.00 B/s  613.26 K/s  0.00 % 99.99 % tendermint --home /tmp/honted_tendermint_test_homedir-1516014162-24328-8fnvf5 --log_level *:info node
24397 be/4 user        0.00 B/s 1144.34 K/s  0.00 % 99.99 % tendermint --home /tmp/honted_tendermint_test_homedir-1516014162-24328-8fnvf5 --log_level *:info node
```

### Disk space

Measure homedir disk size on finishing the test run.
Tendermint only (see note above):
```
+ du -sh /tmp/honted_tendermint_test_homedir-1516017062-28185-1s25vmc
Disk used for homedir:
51M	/tmp/honted_tendermint_test_homedir-1516017062-28185-1s25vmc
```

### Memory

Using `:observer.start; HonteD.Performance...` we can see that
for the run mentioned the total memory consumption grows linearly to ~120MB, with peaks at ~150MB.
Memory usage is due to bloating of `ABCI.State` and `Eventer's` unfinalized transaction queues, quite naturally.

**NOTE** consider sending `SignOff` transactions to relax the latter load.

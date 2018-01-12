### Commit: `2a141d859c6ef7a384519cd9930e5732a6d22670`

```
mix run --no-start -e 'HonteD.Integration.Performance.setup_and_run(5,0,100, %{profiling: :fprof})'
```

1. Tesla's `'Elixir.HonteD.API.TendermintRPC',client,0}` isn't a burden: `286.370` out of `531801.077` in `{'Elixir.HonteD.API',submit_sync,1}`. Likely it only creates a function returning the client.
  - **NOTE** it has been removed in subsequent optimizations, now using persistent Websocket connection
2. in `{'Elixir.HonteD.API.TendermintRPC',broadcast_tx_sync,2}` mostly `Tesla` and `http` request handling
  - see NOTE above
3. `{'Elixir.HonteD.Performance.Scenario','-prepare_send_streams/4-fun-0-',5}` takes `2787.796` which is small but noticable if compared to time spent with `ABCI`. Most of this is spent in creating and signing transactions (equal because both are mocks - hash functions)
4. Time spent with `ABCI` is in total: `{'Elixir.HonteD.ABCI',handle_call,3}` - `16823.502`, of which (compare with 2nd figure):
        { {'Elixir.HonteD.ABCI',handle_call,3},       16782,16823.502,  262.675},     %
        [{{'Elixir.HonteD.TxCodec',decode,1},         16655, 4234.177,  102.471},
         {{'Elixir.HonteD.ABCI',generic_handle_tx,2}, 16655,10432.062,   98.233},
         {{'Elixir.HonteD.ABCI',code,1},              16697,   71.531,   71.531},
         {{'Elixir.HonteD.ABCI.Events',notify,2},     6740,  263.621,   25.692},
         {garbage_collect,                             100,    1.760,    1.760},
         {{'Elixir.HonteD.ABCI.State',hash,1},          42, 1556.553,    0.826},
         {{'Elixir.List.Chars',to_charlist,1},          42,    0.861,    0.160},
         {suspend,                                       1,    0.262,    0.000}]}.
5. By changing `http` communication with Tendermint RPC to `websockets` throughput increased somewhat
        { {'Elixir.HonteD.ABCI',handle_call,3},       21278,14220.715,  225.576},     %
        [{{'Elixir.HonteD.ABCI',generic_handle_tx,2}, 21077, 8787.504,  114.725},
         {{'Elixir.HonteD.TxCodec',decode,1},         21077, 3395.561,  102.433},
         {{'Elixir.HonteD.ABCI',code,1},              21144,   42.785,   42.785},
         {{'Elixir.HonteD.ABCI.Events',notify,2},     9455,  269.409,   33.936},
         {garbage_collect,                             145,    5.149,    5.149},
         {{'Elixir.HonteD.ABCI.State',hash,1},          67, 1493.136,    0.407},
         {{'Elixir.List.Chars',to_charlist,1},          67,    1.595,    0.316}]}.
6. By diversifying the receivers and making the state fill more, (mocked) hashing of the state takes over:
        { {'Elixir.HonteD.ABCI',handle_call,3},       12302,45333.018,  103.391},     %
        [{{'Elixir.HonteD.TxCodec',decode,1},         12152, 1448.985,   44.439},
         {{'Elixir.HonteD.ABCI',generic_handle_tx,2}, 12152, 3935.379,   43.704},
         {{'Elixir.HonteD.ABCI',code,1},              12202,   21.434,   21.434},
         {{'Elixir.HonteD.ABCI.Events',notify,2},     5478,  113.644,   11.457},
         {garbage_collect,                              17,    0.973,    0.973},
         {{'Elixir.HonteD.ABCI.State',hash,1},          50,39707.260,    0.347},
         {{'Elixir.List.Chars',to_charlist,1},          50,    1.952,    0.239}]}.
7. We seem to be at saturation point. There are no evident bottlenecks aside in the node itself
  **TODO** check Poison encoding in `{'Elixir.HonteD.API.TendermintRPC.Websocket','send!',3}`
8. **TODO** get some idea about disk usage/disk space requirements/memory usage and ways to profile

# HonteD

**Quick guide**:

  - `git clone ...`
  - `mix deps.get`
  - `iex -S mix`
  - elsewhere:
    - `tendermint init` (once)
    - `tendermint --log_level "*:info" node` (everytime to start Tendermint)
  - then in the `iex` REPL you can run commands using HonteDAPI, e.g. ones mentioned in demos


Do `tendermint unsafe_reset_all` everytime you want to clean the databases and start from scratch.

Some chaotic messages will print to the REPL, among them the crude state of the application

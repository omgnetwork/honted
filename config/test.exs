use Mix.Config

# NOTE: surpresses all logger output, unfortunately :ex_unit :capture_log has a race cond
config :logger, backends: []

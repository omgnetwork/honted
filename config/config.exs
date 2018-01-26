use Mix.Config

import_config "#{Mix.env}.exs"

import_config "../apps/*/config/config.exs"

config :porcelain, :goon_warn_if_missing, false

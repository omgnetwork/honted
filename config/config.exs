use Mix.Config

import_config "#{Mix.env}.exs"

import_config "../apps/*/config/config.exs"

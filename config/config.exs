import Config

config :joken,
  default_signer: "secret"

Logger.put_module_level(ClusterMonitor, :error)

import Config

jwt_secret =
  if config_env() == :prod do
    System.fetch_env!("JWT_SECRET")
  else
    System.get_env("JWT_SECRET") || "secret"
  end

config :joken,
  default_signer: jwt_secret

# Not sure if this is the correct space, but we import the Facade to expose an interface for humans
import Eddb.Facade

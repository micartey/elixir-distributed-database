defmodule Router.Auth.JwtConfig do
  use Joken.Config

  @secret "my_secret_key"

  def token_config do
    default_claims(default_exp: 3600)
    default_claims(iss: "iex://#{Node.self()}")
  end

  def generate_token(additional_claims) do
    generate_and_sign(additional_claims)
  end

  def generate_token() do
    generate_token(%{})
  end
end

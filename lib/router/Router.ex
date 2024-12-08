defmodule Router.Router do
  alias User.UserServer
  alias Router.Auth.JwtConfig
  alias Router.Authenticate
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)

  # Apply the Authenticate plug to all routes except exempted ones
  plug(Authenticate)

  plug(:dispatch)

  @doc """
  Authenticate the user based on the received payload:

  {
    "email": "...",
    "password:"..."
  }

  This will return - on successfull authentication - a JWT token.
  The token needs to be used for every other endpoint that is not excempted.
  """
  post "/auth" do
    {:ok, body_raw, _conn} = Plug.Conn.read_body(conn)
    body = Poison.Parser.parse!(body_raw, %{keys: :atoms!})

    case User.UserServer.auth_user(body[:username], body[:password]) do
      nil ->
        send_resp(conn, 401, Poison.encode!(%{error: "User not found or incorrect password"}))

      user ->
        {:ok, token, _plain} =
          JwtConfig.generate_token(%{
            "sub" =>
              :crypto.hash(:sha, user.username)
              |> :crypto.bytes_to_integer()
              |> Integer.digits()
              |> Enum.map(fn digit -> <<digit + 100::utf8>> end)
              |> Enum.join(""),
            "permission" => user.permission
          })

        send_resp(conn, 200, Poison.encode!(%{token: token}))
    end
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end

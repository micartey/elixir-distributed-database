defmodule Router.Router do
  alias User.UserServer
  alias Router.Auth.JwtConfig
  alias Router.Authenticate
  use Plug.Router

  plug Plug.Logger
  plug :match

  # Apply the Authenticate plug to all routes except exempted ones
  plug Authenticate

  plug :dispatch


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

    IO.inspect body

    result = GenServer.call(Process.whereis(:user_server), {:auth_user, body[:email], body[:password]})
    IO.inspect result

    # TODO: Search user on all nodes. If they know the user, make sure all of them have the same value
    # If not, there is an error - log it
    # Check what the local storage says - we don't trust the others (maybe imposters?)
    # If we don't know it, abort: Something wen't wrong (Generate trace id)

    # Retrive User from Database based on email and password
    # case Repo.get_by(User, [email: body[:email], password: body[:password]]) do
    #   # Email-Password combo not found
    #   nil -> send_resp(conn, 401, Poison.encode!(%{error: "User not found or incorrect password"}))

    #   # User found - Create JWT-Token
    #   user ->
    #     user = Repo.preload(user, [:permissions])
    #     user_permission = Repo.preload(user.permissions, :permission)

    #     {:ok, token, _plain} = JwtConfig.generate_token(%{
    #       "sub" => user.id,
    #       "uuid" => :crypto.hash(:sha, user.name)
    #       |> :crypto.bytes_to_integer()
    #       |> Integer.digits()
    #       |> Enum.map(fn digit -> <<(digit + 100)::utf8>> end)
    #       |> Enum.join(""),

    #       "permissions" => user_permission |> Enum.map(fn entry -> entry.permission.name end) |> Enum.join(", ")
    #     })

    #     send_resp(conn, 200, Poison.encode!(%{token: token}))
    # end

    send_resp(conn, 401, Poison.encode!(%{error: "User not found or incorrect password"}))
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end

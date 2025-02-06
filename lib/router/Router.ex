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
    "username": "...",
    "password:"..."
  }

  This will return - on successfull authentication - a JWT token.
  The token needs to be used for every other endpoint that is not excempted.
  """
  post "/auth" do
    {:ok, body_raw, _conn} = Plug.Conn.read_body(conn)
    body = Poison.Parser.parse!(body_raw, %{keys: :atoms!})

    case UserServer.auth_user(body[:username], body[:password]) do
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

  @doc """
  Get the value of a key from a topic.
  The URL is strctured as follows: /get?topic=...&key=...
  """
  get "/get" do
    param = fetch_query_params(conn).params

    # ?topic=...&key=...
    topic = param["topic"]
    key = param["key"]

    result =
      Database.Database.get_worker(topic)
      |> GenServer.call({:get, topic, key})

    send_resp(conn, 200, Poison.encode!(result))
  end

  @doc """
  Put a key-value into a topic.

  The body of the request should be a JSON object with the following structure:

  {
    "topic": "...",
    "key": "...",
    "value": "...",
    "old_value": "..." (optional)
  }

  If old_value is present, the put operation will use optimistic locking.
  """
  put "/put" do
    {:ok, body_raw, _conn} = Plug.Conn.read_body(conn)

    body = Poison.Parser.parse!(body_raw, %{keys: :atoms!})

    # Use optimistic locking if old_data is present
    # Otherwise, just put the data into the database
    result =
      if Map.has_key?(body, :old_value) do
        Database.Database.get_worker(body[:topic])
        |> GenServer.call({:put, body[:topic], body[:key], body[:old_value], body[:value]})
      else
        Database.Database.get_worker(body[:topic])
        |> GenServer.call({:put, body[:topic], body[:key], body[:value]})
      end

    # Check if the result is a failure
    case result do
      :fail ->
        send_resp(conn, 409, Poison.encode!(%{error: "Conflict"}))

      _ ->
        send_resp(conn, 200, Poison.encode!(result))
    end
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
